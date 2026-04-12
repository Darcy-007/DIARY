import Foundation
import CoreLocation

struct LocationVisit: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double

    init(coordinate: CLLocationCoordinate2D, timestamp: Date, horizontalAccuracy: Double = 0) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }
}

struct LocationSummary: Codable {
    let visits: [LocationVisit]
}
