import Foundation

protocol DataCollecting {
    func collectPhotos(for window: CollectionWindow) async throws -> [PhotoData]
    func collectHealth(for window: CollectionWindow) async throws -> HealthData
    func collectTransactions(for window: CollectionWindow) async throws -> [TransactionData]
    func collectAll(for window: CollectionWindow) async throws -> CollectedData
}
