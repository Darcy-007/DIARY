import Foundation
@testable import dAIry

final class MockPermissionManager: PermissionManaging {
    var statuses: [DataSource: AuthorizationStatus] = [:]
    var photoAccessResult: AuthorizationStatus = .authorized
    var healthKitAccessResult: AuthorizationStatus = .authorized
    var transactionAccessResult: AuthorizationStatus = .authorized
    var refreshCalled = false

    func requestPhotoAccess() async -> AuthorizationStatus {
        statuses[.photos] = photoAccessResult
        return photoAccessResult
    }

    func requestHealthKitAccess() async -> AuthorizationStatus {
        statuses[.healthKit] = healthKitAccessResult
        return healthKitAccessResult
    }

    func requestTransactionAccess() async -> AuthorizationStatus {
        statuses[.transactions] = transactionAccessResult
        return transactionAccessResult
    }

    func currentStatus(for source: DataSource) -> AuthorizationStatus {
        statuses[source] ?? .notDetermined
    }

    func refreshAllStatuses() async {
        refreshCalled = true
    }
}
