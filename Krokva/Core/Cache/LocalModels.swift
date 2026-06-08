import Foundation
import SwiftData

@Model
final class RecentSearch {
    var address: String
    var cityID: String
    var createdAt: Date

    init(address: String, cityID: String, createdAt: Date = .now) {
        self.address = address
        self.cityID = cityID
        self.createdAt = createdAt
    }
}

@Model
final class CityVote {
    var cityID: String
    var count: Int

    init(cityID: String, count: Int = 0) {
        self.cityID = cityID
        self.count = count
    }
}

@Model
final class CachedDataset {
    var key: String
    var payload: Data
    var expiresAt: Date
    var updatedAt: Date

    init(key: String, payload: Data, expiresAt: Date, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }
}
