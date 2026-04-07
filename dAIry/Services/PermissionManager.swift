import Foundation
import Photos
import HealthKit
import PassKit

final class PermissionManager: PermissionManaging {

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let healthStore: HKHealthStore

    // MARK: - UserDefaults Keys

    private func statusKey(for source: DataSource) -> String {
        "permissionStatus_\(source.rawValue)"
    }

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard,
         healthStore: HKHealthStore = HKHealthStore()) {
        self.userDefaults = userDefaults
        self.healthStore = healthStore
    }

    // MARK: - PermissionManaging

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

        // HealthKit doesn't reveal per-type auth for reads; if the request
        // completes without error we treat it as authorized.
        let status = AuthorizationStatus.authorized
        storeStatus(status, for: .healthKit)
        return status
    }

    func requestTransactionAccess() async -> AuthorizationStatus {
        let available = PKPassLibrary.isPassLibraryAvailable()
        let status: AuthorizationStatus = available ? .authorized : .denied
        storeStatus(status, for: .transactions)
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
                // Permission was revoked outside the app
                storeStatus(.revoked, for: source)
            } else if stored != freshStatus {
                storeStatus(freshStatus, for: source)
            }
        }
    }

    // MARK: - Denial / Revocation Messages

    static func denialMessage(for source: DataSource) -> String {
        switch source {
        case .photos:
            return "Photo library access was denied. Photo data will not be included in diary entries."
        case .healthKit:
            return "HealthKit access was denied. Health data will not be included in diary entries."
        case .transactions:
            return "Transaction data access was denied. Transaction data will not be included in diary entries."
        }
    }

    static func revocationMessage(for source: DataSource) -> String {
        switch source {
        case .photos:
            return "Photo library access was revoked. Photo data will be excluded from future diary entries."
        case .healthKit:
            return "HealthKit access was revoked. Health data will be excluded from future diary entries."
        case .transactions:
            return "Transaction data access was revoked. Transaction data will be excluded from future diary entries."
        }
    }

    // MARK: - Private Helpers

    private func mapPhotoStatus(_ status: PHAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    private func queryFrameworkStatus(for source: DataSource) -> AuthorizationStatus {
        switch source {
        case .photos:
            return mapPhotoStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .healthKit:
            guard HKHealthStore.isHealthDataAvailable() else { return .denied }
            // HealthKit does not expose read authorization status directly.
            // We rely on the stored status; if the user revokes in Settings
            // the next HealthKit query will fail, which we handle at collection time.
            return loadStatus(for: .healthKit)
        case .transactions:
            return PKPassLibrary.isPassLibraryAvailable() ? .authorized : .denied
        }
    }

    // MARK: - Persistence (UserDefaults)

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
