import Foundation
import Photos
import HealthKit
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

final class DataCollector: DataCollecting {

    private let permissionManager: PermissionManaging
    private let healthStore: HKHealthStore
    private let locationTracker: LocationTracker?

    init(permissionManager: PermissionManaging,
         healthStore: HKHealthStore = HKHealthStore(),
         locationTracker: LocationTracker? = nil) {
        self.permissionManager = permissionManager
        self.healthStore = healthStore
        self.locationTracker = locationTracker
    }

    // MARK: - Photo Collection

    func collectPhotos(for window: CollectionWindow) async throws -> [PhotoData] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            window.start as NSDate,
            window.end as NSDate
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var photos: [PhotoData] = []
        let maxPhotos = min(assets.count, 10)
        for i in 0..<maxPhotos {
            let asset = assets.object(at: i)
            let location: CLLocationCoordinate2D? = asset.location?.coordinate
            let jpegData = await fetchImageData(for: asset)
            let photo = PhotoData(
                assetIdentifier: asset.localIdentifier,
                captureDate: asset.creationDate ?? window.start,
                location: location,
                caption: nil,
                imageData: jpegData
            )
            photos.append(photo)
        }
        return photos
    }

    private func fetchImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            let targetSize = CGSize(width: 800, height: 800)
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize,
                contentMode: .aspectFit, options: options
            ) { image, _ in
                #if canImport(UIKit)
                let data = image?.jpegData(compressionQuality: 0.6)
                #else
                let data: Data? = nil
                #endif
                continuation.resume(returning: data)
            }
        }
    }

    // MARK: - Health Data Collection

    func collectHealth(for window: CollectionWindow) async throws -> HealthData {
        let stepCount = try await queryStatistics(for: HKQuantityType(.stepCount), unit: .count(), start: window.start, end: window.end)
        let distance = try await queryStatistics(for: HKQuantityType(.distanceWalkingRunning), unit: .meter(), start: window.start, end: window.end)
        let energy = try await queryStatistics(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), start: window.start, end: window.end)
        return HealthData(stepCount: Int(stepCount), walkingRunningDistance: distance, activeEnergyBurned: energy)
    }

    private func queryStatistics(for quantityType: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error { continuation.resume(throwing: error); return }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Collect All

    func collectAll(for window: CollectionWindow) async throws -> CollectedData {
        var photos: [PhotoData] = []
        var health: HealthData? = nil
        var locationVisits: [LocationVisit] = []

        let photoStatus = permissionManager.currentStatus(for: .photos)
        let healthStatus = permissionManager.currentStatus(for: .healthKit)
        print("[dAIry] Permission statuses — photos: \(photoStatus), healthKit: \(healthStatus)")

        if photoStatus == .authorized {
            do {
                photos = try await collectPhotos(for: window)
                print("[dAIry] Collected \(photos.count) photos")
            } catch {
                print("[dAIry] Photo collection error: \(error)")
            }
        } else {
            print("[dAIry] Skipping photos — status: \(photoStatus)")
        }

        if healthStatus == .authorized {
            do {
                health = try await collectHealth(for: window)
                print("[dAIry] Collected health — steps: \(health?.stepCount ?? 0)")
            } catch {
                print("[dAIry] Health collection error: \(error)")
            }
        } else {
            print("[dAIry] Skipping health — status: \(healthStatus)")
        }

        if let tracker = locationTracker,
           (tracker.authorizationStatus == .authorizedAlways || tracker.authorizationStatus == .authorizedWhenInUse) {
            locationVisits = tracker.visits(for: window)
            print("[dAIry] Collected \(locationVisits.count) location visits")
        } else {
            print("[dAIry] Skipping location — tracker: \(locationTracker != nil), auth: \(locationTracker?.authorizationStatus.rawValue ?? -1)")
        }

        return CollectedData(window: window, photos: photos, health: health, locationVisits: locationVisits)
    }
}
