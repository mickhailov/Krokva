import CoreLocation
import Foundation
import MapKit

// Nearby-schools resolution for Winnipeg: assigned/nearby schools from the Krokva server,
// MapKit fallback, and the Manitoba school-directory enrichment. Extracted from the main
// provider to keep the per-domain fetch logic navigable.
extension WinnipegProvider {
    // Called by the report fan-out in WinnipegProvider.fetchReport, so it must be reachable
    // across the file boundary (internal rather than private).
    func fetchNearbySchools(property: PropertyAssessment?) async -> [SchoolAmenity] {
        guard let dataset = datasets.schools,
              let subject = property?.coordinate else { return [] }

        if let serverSchools = await fetchServerNearbySchools(subject: subject, address: property?.fullAddress), !serverSchools.isEmpty {
            return serverSchools
        }

        // School Zone Signage carries one Point per sign, so a single school appears as
        // many rows. Pull every sign within range, then collapse to one entry per school
        // using the averaged sign location as the school's approximate position. Keep a
        // wider candidate pool because some school-zone signs sit farther from the school
        // building than the building is from the subject property.
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "school,street_name,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),3500) AND school IS NOT NULL"),
            URLQueryItem(name: "$limit", value: "900")
        ])) ?? []

        struct SchoolAccumulator { var latSum = 0.0; var lonSum = 0.0; var count = 0; var street: String? }
        var bySchool: [String: SchoolAccumulator] = [:]
        for row in rows {
            guard let name = row.string("school")?.trimmingCharacters(in: .whitespacesAndNewlines).repairedFrenchCivicName,
                  !name.isEmpty,
                  let coordinate = parseCoordinate(row) else { continue }
            var acc = bySchool[name] ?? SchoolAccumulator()
            acc.latSum += coordinate.latitude
            acc.lonSum += coordinate.longitude
            acc.count += 1
            if acc.street == nil { acc.street = row.string("street_name") }
            bySchool[name] = acc
        }

        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let signageCandidates = bySchool.compactMap { name, acc -> (school: SchoolAmenity, distance: Double)? in
            guard acc.count > 0 else { return nil }
            let coordinate = CLLocationCoordinate2D(
                latitude: acc.latSum / Double(acc.count),
                longitude: acc.lonSum / Double(acc.count)
            )
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let school = SchoolAmenity(
                name: name,
                address: acc.street ?? "Winnipeg, MB",
                distanceDescription: distanceDescription(meters: distance),
                distanceMeters: distance,
                walkingTimeDescription: walkingTimeDescription(meters: distance),
                source: "Winnipeg school-zone signs",
                coordinate: coordinate
            )
            return (school, distance)
        }

        let mapKitCandidates = await fetchMapKitNearbySchools(subject: subject)
        let candidates = mergedSchoolCandidates(signageCandidates + mapKitCandidates)
            .sorted { $0.distance < $1.distance }
            .prefix(24)

        var enriched: [(school: SchoolAmenity, distance: Double)] = []
        await withTaskGroup(of: (SchoolAmenity, Double).self) { group in
            for candidate in candidates {
                group.addTask { [weak self] in
                    guard let self else { return candidate }
                    guard let info = await self.fetchSchoolDirectoryInfo(for: candidate.school) else {
                        return candidate
                    }
                    var school = candidate.school
                    if let address = info.address { school.address = address }
                    school.grades = info.grades
                    school.schoolType = schoolTypeLabel(division: info.division)
                    school.programs = programTags(from: info.program)
                    school.source = "Manitoba school directory"
                    return (school, candidate.distance)
                }
            }

            for await candidate in group {
                enriched.append(candidate)
            }
        }

        let addressCoordinates = await geocodeSchoolAddresses(enriched.map(\.school.address))
        return enriched.map { candidate -> (school: SchoolAmenity, distance: Double) in
            var school = candidate.school
            guard let coordinate = addressCoordinates[addressSearchKey(school.address)] else {
                return candidate
            }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            school.coordinate = coordinate
            school.distanceMeters = distance
            school.distanceDescription = distanceDescription(meters: distance)
            school.walkingTimeDescription = walkingTimeDescription(meters: distance)
            return (school, distance)
        }
        .sorted { $0.distance < $1.distance }
        .prefix(6)
        .map(\.school)
    }

    private func fetchServerNearbySchools(subject: CLLocationCoordinate2D, address: String?) async -> [SchoolAmenity]? {
        var components = URLComponents()
        components.scheme = scheme
        let parts = domain.split(separator: ":", maxSplits: 1)
        components.host = String(parts[0])
        if parts.count == 2, let port = Int(parts[1]) { components.port = port }
        components.path = "/api/schools/nearby"
        var queryItems = [
            URLQueryItem(name: "lat", value: "\(subject.latitude)"),
            URLQueryItem(name: "lon", value: "\(subject.longitude)"),
            URLQueryItem(name: "radius", value: "3000"),
            URLQueryItem(name: "limit", value: "8")
        ]
        if let address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
            let decoded = try JSONDecoder().decode(ServerSchoolsResponse.self, from: data)
            return (decoded.assigned + decoded.nearby).map { row in
                SchoolAmenity(
                    id: row.id.flatMap(UUID.init(uuidString:)) ?? UUID(),
                    name: row.name,
                    address: row.address,
                    distanceDescription: row.distanceDescription,
                    distanceMeters: row.distanceMeters,
                    walkingTimeDescription: row.walkingTimeDescription,
                    grades: row.grades,
                    schoolType: row.schoolType,
                    programs: row.programs ?? [],
                    isAssigned: row.isAssigned ?? false,
                    source: row.source,
                    coordinate: row.coordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                )
            }
        } catch {
            return nil
        }
    }

    private func fetchMapKitNearbySchools(subject: CLLocationCoordinate2D) async -> [(school: SchoolAmenity, distance: Double)] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "school"
        request.region = MKCoordinateRegion(center: subject, latitudinalMeters: 3000, longitudinalMeters: 3000)
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
            return response.mapItems.compactMap { item in
                guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      isSchoolLikeName(name) else { return nil }
                let coordinate = item.placemark.coordinate
                let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
                guard distance <= 3000 else { return nil }
                let address = mapItemAddress(item) ?? item.placemark.title ?? "Winnipeg, MB"
                let school = SchoolAmenity(
                    name: name.repairedFrenchCivicName,
                    address: address,
                    distanceDescription: distanceDescription(meters: distance),
                    distanceMeters: distance,
                    walkingTimeDescription: walkingTimeDescription(meters: distance),
                    source: "Apple Maps",
                    coordinate: coordinate
                )
                return (school, distance)
            }
        } catch {
            return []
        }
    }

    private func mergedSchoolCandidates(_ candidates: [(school: SchoolAmenity, distance: Double)]) -> [(school: SchoolAmenity, distance: Double)] {
        var byName: [String: (school: SchoolAmenity, distance: Double)] = [:]
        for candidate in candidates {
            let key = normalizedSchoolName(candidate.school.name)
            guard !key.isEmpty else { continue }
            if let existing = byName[key], existing.distance <= candidate.distance { continue }
            byName[key] = candidate
        }
        return Array(byName.values)
    }

    private func isSchoolLikeName(_ name: String) -> Bool {
        let normalized = normalizedSchoolName(name)
        return normalized.contains("school")
            || normalized.contains("academy")
            || normalized.contains("collegiate")
            || normalized.contains("college")
            || normalized.contains("montessori")
            || normalized.contains("learning centre")
            || normalized.contains("ecole")
    }

    private func mapItemAddress(_ item: MKMapItem) -> String? {
        let placemark = item.placemark
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: " ")
            .nilIfEmpty
        let city = [placemark.locality, placemark.administrativeArea]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
        return [street, city].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
    }

    private func walkingTimeDescription(meters: Double) -> String {
        let minutes = max(1, Int((meters / 80.0).rounded(.up)))
        return "\(minutes) min walk"
    }

    private func schoolTypeLabel(division: String?) -> String? {
        guard let division = division?.trimmingCharacters(in: .whitespacesAndNewlines), !division.isEmpty else {
            return nil
        }
        if division.localizedCaseInsensitiveContains("Independent") {
            return "Independent"
        }
        if division.localizedCaseInsensitiveContains("Catholic") {
            return "Catholic"
        }
        if division.localizedCaseInsensitiveContains("Winnipeg School Division") {
            return "Public · Winnipeg SD"
        }
        if division.localizedCaseInsensitiveContains("Louis Riel School Division") {
            return "Public · Louis Riel SD"
        }
        return division
            .replacingOccurrences(of: "School Division", with: "SD")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func programTags(from value: String?) -> [String] {
        guard let value else { return [] }
        let raw = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var tags: [String] = []
        func append(_ tag: String) {
            if !tags.contains(tag) { tags.append(tag) }
        }

        for item in raw {
            if item.localizedCaseInsensitiveContains("Early Immersion") {
                append("Early Immersion")
            } else if item.localizedCaseInsensitiveContains("Late Immersion") {
                append("Late Immersion")
            } else if item.localizedCaseInsensitiveContains("Middle Immersion") {
                append("Middle Immersion")
            } else if item.localizedCaseInsensitiveContains("French") {
                append("French")
            } else if item.localizedCaseInsensitiveContains("English") {
                append("English")
            } else if item.localizedCaseInsensitiveContains("Montessori") {
                append("Montessori")
            } else if item.count <= 22 {
                append(item)
            }
        }
        return Array(tags.prefix(4))
    }

    private func fetchSchoolDirectoryInfo(for school: SchoolAmenity) async -> SchoolDirectoryInfo? {
        var ids: [String] = []
        for term in schoolDirectorySearchTerms(for: school.name) {
            ids.append(contentsOf: await fetchManitobaSchoolIDs(matching: term))
        }
        ids = Array(NSOrderedSet(array: ids).compactMap { $0 as? String })
        guard !ids.isEmpty else { return nil }

        var matches: [SchoolDirectoryInfo] = []
        await withTaskGroup(of: SchoolDirectoryInfo?.self) { group in
            for id in ids.prefix(8) {
                group.addTask { await self.fetchManitobaSchoolDetail(id: id) }
            }
            for await info in group {
                if let info { matches.append(info) }
            }
        }

        let schoolName = normalizedSchoolName(school.name)
        let street = streetCore(school.address)
        return matches
            .filter { info in
                guard let address = info.address else { return false }
                return address.localizedCaseInsensitiveContains("Winnipeg")
                    || info.division?.localizedCaseInsensitiveContains("Winnipeg") == true
                    || streetCore(address) == street
            }
            .sorted { lhs, rhs in
                scoreSchoolDirectoryMatch(lhs, schoolName: schoolName, street: street)
                    > scoreSchoolDirectoryMatch(rhs, schoolName: schoolName, street: street)
            }
            .first
    }

    private func fetchManitobaSchoolIDs(matching name: String) async -> [String] {
        guard let url = URL(string: "https://web.gov.mb.ca/school/school?action=school") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [URLQueryItem(name: "SchoolText", value: name)]
        let query = body.percentEncodedQuery ?? "SchoolText=\(formEncoded(name))"
        request.httpBody = "\(query)&SchoolSearch=Submit".data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                  let html = String(data: data, encoding: .utf8) else { return [] }
            return regexCaptures(pattern: #"singleschool&name=(\d+)""#, in: html)
        } catch {
            return []
        }
    }

    private func fetchManitobaSchoolDetail(id: String) async -> SchoolDirectoryInfo? {
        guard let url = URL(string: "https://web.gov.mb.ca/school/school?action=singleschool&name=\(id)") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                  let html = String(data: data, encoding: .utf8) else { return nil }

            let rawName = firstRegexCapture(pattern: #"<div class="sc_name">([^<]+)</div>"#, in: html)
            let name = rawName?
                .htmlDecoded
                .replacingOccurrences(of: #"\s*#\d+$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !name.isEmpty else { return nil }

            let address = firstRegexCapture(pattern: #"<div class="sc_name">[^<]+</div><div>(.*?)<br />"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let city = firstRegexCapture(pattern: #"<br />([^<]*Manitoba)<br />"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fullAddress = [address, city].compactMap { $0?.nilIfEmpty }.joined(separator: ", ").nilIfEmpty
            let grades = firstRegexCapture(pattern: #"<strong>Grades:</strong>(?:&nbsp;|\s)*([^<]+)<br />"#, in: html)?
                .htmlDecoded
                .replacingOccurrences(of: " to ", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let program = firstRegexCapture(pattern: #"<strong>Program:</strong>(?:&nbsp;|\s)*([^<]+)</div>"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let division = firstRegexCapture(pattern: #"<div class="sc_div">\s*([^<]+)</div>"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return SchoolDirectoryInfo(name: name, address: fullAddress, grades: grades?.nilIfEmpty, division: division?.nilIfEmpty, program: program?.nilIfEmpty)
        } catch {
            return nil
        }
    }

    private func geocodeSchoolAddresses(_ addresses: [String]) async -> [String: CLLocationCoordinate2D] {
        guard let dataset = datasets.assessment else { return [:] }
        let keys = Set(addresses.map(addressSearchKey).filter { !$0.isEmpty })
        var byStreet: [String: Set<String>] = [:]
        for key in keys {
            let parts = key.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            byStreet[String(parts[1]), default: []].insert(String(parts[0]))
        }

        var result: [String: CLLocationCoordinate2D] = [:]
        await withTaskGroup(of: [(String, CLLocationCoordinate2D)].self) { group in
            for (street, nums) in byStreet {
                let numList = nums.map { "'\($0)'" }.joined(separator: ",")
                let token = escaped(street)
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    let rows = (try? await self.fetch(dataset, queryItems: [
                        URLQueryItem(name: "$select", value: "street_number,street_name,centroid_lat,centroid_lon,geometry"),
                        URLQueryItem(name: "$where", value: "upper(street_name)='\(token)' AND street_number in (\(numList))"),
                        URLQueryItem(name: "$limit", value: "50")
                    ])) ?? []
                    return rows.compactMap { row -> (String, CLLocationCoordinate2D)? in
                        guard let number = row.string("street_number"),
                              let coordinate = self.parseCoordinate(row) else { return nil }
                        return ("\(number) \(street)", coordinate)
                    }
                }
            }

            for await pairs in group {
                for (key, coordinate) in pairs where result[key] == nil {
                    result[key] = coordinate
                }
            }
        }
        return result
    }

    private func schoolDirectorySearchTerms(for name: String) -> [String] {
        var terms: [String] = []
        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !terms.contains(trimmed) { terms.append(trimmed) }
        }

        append(name)
        let withoutParenthetical = name
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        append(withoutParenthetical)
        append(withoutParenthetical.replacingOccurrences(of: "Savior", with: "Saviour", options: [.caseInsensitive]))
        append(withoutParenthetical.replacingOccurrences(of: "Saviour", with: "Savior", options: [.caseInsensitive]))
        return terms
    }

    private func addressSearchKey(_ address: String) -> String {
        let firstLine = address.split(separator: ",", maxSplits: 1).first.map(String.init) ?? address
        let parts = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, Int(parts[0]) != nil else { return "" }
        let street = streetCore(String(parts[1]))
        guard !street.isEmpty else { return "" }
        return "\(parts[0]) \(street)"
    }

    private func normalizedSchoolName(_ value: String) -> String {
        value.htmlDecoded
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_CA"))
            .replacingOccurrences(of: #"(?i)^ecole\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scoreSchoolDirectoryMatch(_ info: SchoolDirectoryInfo, schoolName: String, street: String) -> Int {
        let candidateName = normalizedSchoolName(info.name)
        var score = 0
        if candidateName == schoolName { score += 100 }
        if candidateName.contains(schoolName) || schoolName.contains(candidateName) { score += 30 }
        if let address = info.address, streetCore(address) == street { score += 25 }
        if info.address?.localizedCaseInsensitiveContains("Winnipeg") == true { score += 10 }
        if info.division?.localizedCaseInsensitiveContains("Winnipeg") == true { score += 10 }
        return score
    }

    private func formEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func firstRegexCapture(pattern: String, in text: String) -> String? {
        regexCaptures(pattern: pattern, in: text).first
    }

    private func regexCaptures(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange])
        }
    }
}
