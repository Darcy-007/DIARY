import CoreLocation
import Foundation

struct PhotoData {
    let assetIdentifier: String
    let captureDate: Date
    let location: CLLocationCoordinate2D?
    let caption: String?
    let imageData: Data?  // JPEG image data for sending to Gemini

    init(assetIdentifier: String, captureDate: Date, location: CLLocationCoordinate2D? = nil, caption: String? = nil, imageData: Data? = nil) {
        self.assetIdentifier = assetIdentifier
        self.captureDate = captureDate
        self.location = location
        self.caption = caption
        self.imageData = imageData
    }
}

struct PhotoReference: Codable {
    let assetIdentifier: String
    let captureDate: Date
    let caption: String?
}
