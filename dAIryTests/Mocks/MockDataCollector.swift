import Foundation
@testable import dAIry

final class MockDataCollector: DataCollecting {
    var photosResult: [PhotoData] = []
    var healthResult: HealthData = HealthData(stepCount: 0, walkingRunningDistance: 0, activeEnergyBurned: 0)
    var transactionsResult: [TransactionData] = []
    var collectAllResult: CollectedData?
    var shouldThrow = false
    var lastWindow: CollectionWindow?

    func collectPhotos(for window: CollectionWindow) async throws -> [PhotoData] {
        lastWindow = window
        if shouldThrow { throw NSError(domain: "MockDataCollector", code: 1) }
        return photosResult
    }

    func collectHealth(for window: CollectionWindow) async throws -> HealthData {
        lastWindow = window
        if shouldThrow { throw NSError(domain: "MockDataCollector", code: 2) }
        return healthResult
    }

    func collectTransactions(for window: CollectionWindow) async throws -> [TransactionData] {
        lastWindow = window
        if shouldThrow { throw NSError(domain: "MockDataCollector", code: 3) }
        return transactionsResult
    }

    func collectAll(for window: CollectionWindow) async throws -> CollectedData {
        lastWindow = window
        if shouldThrow { throw NSError(domain: "MockDataCollector", code: 4) }
        if let result = collectAllResult { return result }
        return CollectedData(
            window: window,
            photos: photosResult,
            health: healthResult.stepCount == 0 && healthResult.walkingRunningDistance == 0 && healthResult.activeEnergyBurned == 0 ? nil : healthResult,
            transactions: transactionsResult
        )
    }
}
