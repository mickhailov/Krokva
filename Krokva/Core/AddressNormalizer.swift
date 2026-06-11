import Foundation

struct NormalizedAddress: Hashable, Codable {
    var raw: String
    var civicNumber: Int?
    var streetName: String
    var cityName: String
    var provinceCode: String?

    var displayAddress: String { raw }
}

protocol AddressNormalizer {
    func normalize(_ input: String) -> NormalizedAddress
    func streetVariants(for address: NormalizedAddress) -> [String]
}

struct DefaultAddressNormalizer: AddressNormalizer {
    func normalize(_ input: String) -> NormalizedAddress {
        let parts = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let streetPart = parts.first ?? input
        let number = streetPart.split(separator: " ").first.flatMap { Int($0) }
        let street = streetPart
            .replacingOccurrences(of: #"^\d+\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let city = parts.dropFirst().first ?? ""
        return NormalizedAddress(raw: input, civicNumber: number, streetName: street, cityName: city, provinceCode: nil)
    }

    func streetVariants(for address: NormalizedAddress) -> [String] {
        [address.streetName]
    }
}

struct WinnipegAddressNormalizer: AddressNormalizer {
    func normalize(_ input: String) -> NormalizedAddress {
        DefaultAddressNormalizer().normalize(input)
    }

    func streetVariants(for address: NormalizedAddress) -> [String] {
        let base = address.streetName
        let suffixPattern = #"(?i)\b(avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|lane|ln|court|crt|ct|trail|trl|close|bay|bv|terrace|terr|circle|cir|grove|grv|heights|hts|run|bend|glen|mews)\b"#
        let upperNoSuffix = base
            .replacingOccurrences(of: suffixPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let av = base.replacingOccurrences(of: "Avenue", with: "Av", options: .caseInsensitive)
        let ave = base.replacingOccurrences(of: "Avenue", with: "Ave", options: .caseInsensitive)
        let lane = base.replacingOccurrences(of: #"(?i)\bLn\b"#, with: "Lane", options: .regularExpression)
        return Array(Set([base, av, ave, lane, upperNoSuffix])).filter { !$0.isEmpty }
    }
}
