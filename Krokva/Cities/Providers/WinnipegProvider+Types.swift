import Foundation

// Internal helper models for `WinnipegProvider`'s fetch fan-out. Kept in their own file so
// the provider's domain extensions (schools, health, …) can share them; they are used only
// within the Winnipeg provider and carry no behaviour.

struct SchoolDivisionBoundaryInfo {
    var name: String?
    var code: String?
    var website: String?
}

struct SchoolDirectoryInfo {
    var name: String
    var address: String?
    var grades: String?
    var division: String?
    var program: String?
}

struct ServerSchoolsResponse: Decodable {
    var assigned: [ServerSchool]
    var nearby: [ServerSchool]
}

struct ServerSchool: Decodable {
    var id: String?
    var name: String
    var address: String
    var distanceDescription: String
    var distanceMeters: Double?
    var walkingTimeDescription: String?
    var grades: String?
    var schoolType: String?
    var programs: [String]?
    var isAssigned: Bool?
    var source: String?
    var coordinate: ServerCoordinate?
}

struct ServerCoordinate: Decodable {
    var latitude: Double
    var longitude: Double
}

struct CensusBoundaryCandidate {
    var boundaryType: String
    var names: [String]
    var displayName: String
}

// Aggregates geocode sub-progress from two parallel tasks into a single 0…1 value.
actor GeoProgressAggregator {
    private var permits: Double = 0
    private var vacants: Double = 0
    var combined: Double { (permits + vacants) / 2 }
    func setPermits(_ v: Double) { permits = v }
    func setVacants(_ v: Double) { vacants = v }
}
