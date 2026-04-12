import Foundation
import SwiftData

@Model
class DiaryEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var text: String
    var photoReferences: [PhotoReference]
    var healthSummary: HealthSummary?
    var locationSummary: LocationSummary?
    var createdAt: Date
    var isSupplemental: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        text: String,
        photoReferences: [PhotoReference] = [],
        healthSummary: HealthSummary? = nil,
        locationSummary: LocationSummary? = nil,
        createdAt: Date = Date(),
        isSupplemental: Bool = false
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.photoReferences = photoReferences
        self.healthSummary = healthSummary
        self.locationSummary = locationSummary
        self.createdAt = createdAt
        self.isSupplemental = isSupplemental
    }
}
