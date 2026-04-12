import Foundation

protocol DataCollecting {
    func collectPhotos(for window: CollectionWindow) async throws -> [PhotoData]
    func collectHealth(for window: CollectionWindow) async throws -> HealthData
    func collectAll(for window: CollectionWindow) async throws -> CollectedData
}
