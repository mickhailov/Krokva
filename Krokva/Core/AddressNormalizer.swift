import Foundation

struct NormalizedAddress: Hashable {
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
        let upperNoSuffix = base
            .replacingOccurrences(of: #"(?i)\b(avenue|ave|av)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(street|st)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let av = base.replacingOccurrences(of: "Avenue", with: "Av")
        let ave = base.replacingOccurrences(of: "Avenue", with: "Ave")
        return Array(Set([base, av, ave, upperNoSuffix])).filter { !$0.isEmpty }
    }
}
