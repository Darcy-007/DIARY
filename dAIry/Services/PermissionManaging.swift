import Foundation

protocol PermissionManaging {
    func requestPhotoAccess() async -> AuthorizationStatus
    func requestHealthKitAccess() async -> AuthorizationStatus
    func currentStatus(for source: DataSource) -> AuthorizationStatus
    func refreshAllStatuses() async
}
