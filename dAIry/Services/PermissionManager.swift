import Foundation
import Photos
import HealthKit
import CoreLocation

final class PermissionManager: PermissionManaging {

    private let userDefaults: UserDefaults
    private let healthStore: HKHealthStore

    private func statusKey(for source: DataSource) -> String {
        "permissionStatus_\(source.rawValue)"
    }

    init(userDefaults: UserDefaults = .standard,
         healthStore: HKHealthStore = HKHealthStore()) {
        self.userDefaults = userDefaults
        self.healthStore = healthStore
    }

    func requestPhotoAccess() async -> AuthorizationStatus {
        let phStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if phStatus == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            let status = mapPhotoStatus(granted)
            storeStatus(status, for: .photos)
            return status
        }
        let status = mapPhotoStatus(phStatus)
        storeStatus(status, for: .photos)
        return status
    }

    func requestHealthKitAccess() async -> AuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            let status = AuthorizationStatus.denied
            storeStatus(status, for: .healthKit)
            return status
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        } catch {
            let status = AuthorizationStatus.denied
            storeStatus(status, for: .healthKit)
            return status
        }

        let status = AuthorizationStatus.authorized
        storeStatus(status, for: .healthKit)
        return status
    }

    func currentStatus(for source: DataSource) -> AuthorizationStatus {
        loadStatus(for: source)
    }

    func refreshAllStatuses() async {
        for source in DataSource.allCases {
            let freshStatus = queryFrameworkStatus(for: source)
            let stored = loadStatus(for: source)
            if stored == .authorized && freshStatus != .authorized {
                storeStatus(.revoked, for: source)
            } else if stored != freshStatus {
                storeStatus(freshStatus, for: source)
            }
        }
    }

    static func denialMessage(for source: DataSource) -> String {
        switch source {
        case .photos:
            return "Photo library access was denied. Photo data will not be included in diary entries."
        case .healthKit:
            return "HealthKit access was denied. Health data will not be included in diary entries."
        case .location:
            return "Location access was denied. Location data will not be included in diary entries."
        }
    }

    static func revocationMessage(for source: DataSource) -> String {
        switch source {
        case .photos:
            return "Photo library access was revoked. Photo data will be excluded from future diary entries."
        case .healthKit:
            return "HealthKit access was revoked. Health data will be excluded from future diary entries."
        case .location:
            return "Location access was revoked. Location data will be excluded from future diary entries."
        }
    }

    private func mapPhotoStatus(_ status: PHAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .authorized, .limited: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    private func queryFrameworkStatus(for source: DataSource) -> AuthorizationStatus {
        switch source {
        case .photos:
            return mapPhotoStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .healthKit:
            guard HKHealthStore.isHealthDataAvailable() else { return .denied }
            return loadStatus(for: .healthKit)
        case .location:
            let status = CLLocationManager().authorizationStatus
            switch status {
            case .authorizedAlways, .authorizedWhenInUse: return .authorized
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }
        }
    }

    private func storeStatus(_ status: AuthorizationStatus, for source: DataSource) {
        userDefaults.set(status.rawValue, forKey: statusKey(for: source))
    }

    private func loadStatus(for source: DataSource) -> AuthorizationStatus {
        guard let raw = userDefaults.string(forKey: statusKey(for: source)),
              let status = AuthorizationStatus(rawValue: raw) else {
            return .notDetermined
        }
        return status
    }
}
