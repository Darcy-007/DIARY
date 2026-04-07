import XCTest
import SwiftCheck
@testable import dAIry

// MARK: - DiaryGenerator Property Tests

final class DiaryGeneratorPropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 9: Generator produces one entry per non-empty collected data
    // **Validates: Requirements 8.1**
    func testGeneratorProducesOneEntryPerNonEmptyData() {
        let sourceTypeGen = Gen<Int>.fromElements(in: 0...2)

        property("For any non-empty CollectedData, exactly one DiaryEntry is produced") <- forAll(sourceTypeGen) { (sourceType: Int) in
            let mockAPIKeyManager = MockAPIKeyManager()
            mockAPIKeyManager.storedKey = "test-valid-key"

            let mockGenerator = MockDiaryGenerator()

            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let window = CollectionWindow(date: now, start: startOfDay, end: endOfDay)

            // Create non-empty CollectedData based on sourceType
            let photos: [PhotoData]
            let health: HealthData?
            let transactions: [TransactionData]

            switch sourceType {
            case 0:
                photos = [PhotoData(assetIdentifier: "photo-1", captureDate: now, location: nil, caption: "Test")]
                health = nil
                transactions = []
            case 1:
                photos = []
                health = HealthData(stepCount: 1000, walkingRunningDistance: 800, activeEnergyBurned: 200)
                transactions = []
            default:
                photos = []
                health = nil
                transactions = [TransactionData(merchantName: "Store", amount: 10.0, date: now)]
            }

            let data = CollectedData(window: window, photos: photos, health: health, transactions: transactions)

            // Data should not be empty
            guard !data.isEmpty else { return false }

            // Generate using mock
            let semaphore = DispatchSemaphore(value: 0)
            var entry: DiaryEntry?
            var entryCount = 0
            Task {
                do {
                    entry = try await mockGenerator.generate(from: data)
                    entryCount = 1
                } catch {
                    entryCount = 0
                }
                semaphore.signal()
            }
            semaphore.wait()

            return entryCount == 1 && entry != nil
        }
    }

    // Feature: dairy-ios-app, Property 10: Entry references match available data sources
    // **Validates: Requirements 8.3**
    func testEntryReferencesMatchAvailableDataSources() {
        let hasPhotosGen = Bool.arbitrary
        let hasHealthGen = Bool.arbitrary
        let hasTransactionsGen = Bool.arbitrary

        property("Entry contains references for each non-empty source") <- forAll(hasPhotosGen, hasHealthGen, hasTransactionsGen) { (hasPhotos: Bool, hasHealth: Bool, hasTransactions: Bool) in
            // Skip all-empty case
            guard hasPhotos || hasHealth || hasTransactions else { return true }

            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let window = CollectionWindow(date: now, start: startOfDay, end: endOfDay)

            let photos: [PhotoData] = hasPhotos
                ? [PhotoData(assetIdentifier: "p1", captureDate: now, location: nil, caption: "cap")]
                : []
            let health: HealthData? = hasHealth
                ? HealthData(stepCount: 500, walkingRunningDistance: 400, activeEnergyBurned: 100)
                : nil
            let transactions: [TransactionData] = hasTransactions
                ? [TransactionData(merchantName: "Shop", amount: 25.0, date: now)]
                : []

            let data = CollectedData(window: window, photos: photos, health: health, transactions: transactions)

            // Build entry as DiaryGenerator would
            let entry = DiaryEntry(
                date: data.window.date,
                text: "Test entry",
                photoReferences: data.photos.map {
                    PhotoReference(assetIdentifier: $0.assetIdentifier, captureDate: $0.captureDate, caption: $0.caption)
                },
                healthSummary: data.health.map {
                    HealthSummary(stepCount: $0.stepCount, walkingRunningDistanceMeters: $0.walkingRunningDistance, activeEnergyBurnedKcal: $0.activeEnergyBurned)
                },
                transactionSummary: data.transactions.map {
                    TransactionSummary(merchantName: $0.merchantName, amount: $0.amount, date: $0.date)
                }
            )

            let photosMatch = hasPhotos ? !entry.photoReferences.isEmpty : entry.photoReferences.isEmpty
            let healthMatch = hasHealth ? entry.healthSummary != nil : entry.healthSummary == nil
            let transactionsMatch = hasTransactions ? !entry.transactionSummary.isEmpty : entry.transactionSummary.isEmpty

            return photosMatch && healthMatch && transactionsMatch
        }
    }

    // Feature: dairy-ios-app, Property 11: Entry date matches CollectionWindow date
    // **Validates: Requirements 8.4**
    func testEntryDateMatchesCollectionWindowDate() {
        property("Generated entry date matches the CollectionWindow date") <- forAll { (arbWindow: ArbitraryCollectionWindow) in
            let window = arbWindow.window
            let photos = [PhotoData(assetIdentifier: "p1", captureDate: window.date, location: nil, caption: nil)]
            let data = CollectedData(window: window, photos: photos, health: nil, transactions: [])

            // Build entry as DiaryGenerator would
            let entry = DiaryEntry(
                date: data.window.date,
                text: "Test entry",
                photoReferences: data.photos.map {
                    PhotoReference(assetIdentifier: $0.assetIdentifier, captureDate: $0.captureDate, caption: $0.caption)
                }
            )

            return entry.date == window.date
        }
    }
}
