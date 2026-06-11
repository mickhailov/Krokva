import Foundation

struct WRHAEmergencyWaitTime: Identifiable {
    var id: String { facilityName }
    var facilityName: String
    var waitingPatients: Int
    var treatingPatients: Int
    var waitMinutes: Int
    var updatedAt: String?
}

final class WRHAWaitTimesClient {
    private let session: URLSession
    private let waitTimesURL = URL(string: "https://wrha.mb.ca/wait-times/emergency/")!

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: configuration)
    }

    func emergencyWaitTimes() async throws -> [WRHAEmergencyWaitTime] {
        let (data, response) = try await session.data(from: waitTimesURL)
        guard let http = response as? HTTPURLResponse else { return [] }
        guard 200..<300 ~= http.statusCode else { throw OpenDataError.badResponse(http.statusCode) }
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return parseEmergencyWaitTimes(from: html)
    }

    private func parseEmergencyWaitTimes(from html: String) -> [WRHAEmergencyWaitTime] {
        let text = normalizedText(from: html)
        let updatedAt = firstMatch(in: text, pattern: #"Last updated:\s*([0-9]{1,2}:[0-9]{2}\s*[AP]M)"#)
        let facilityNames = [
            "St. Boniface Hospital",
            "Health Sciences Centre - Children's",
            "Health Sciences Centre - Adult",
            "Grace Hospital"
        ]

        return facilityNames.compactMap { name in
            let pattern = NSRegularExpression.escapedPattern(for: name) + #"\s+(\d+)\s+(\d+)\s+([0-9]+(?:\.[0-9]+)?)\s+hrs"#
            let match = firstGroups(in: text, pattern: pattern)
            guard match.count == 3,
                  let waiting = Int(match[0]),
                  let treating = Int(match[1]),
                  let hours = Double(match[2]) else { return nil }

            return WRHAEmergencyWaitTime(
                facilityName: name,
                waitingPatients: waiting,
                treatingPatients: treating,
                waitMinutes: Int((hours * 60).rounded()),
                updatedAt: updatedAt
            )
        }
    }

    private func normalizedText(from html: String) -> String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        firstGroups(in: text, pattern: pattern).first
    }

    private func firstGroups(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return [] }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }
}
