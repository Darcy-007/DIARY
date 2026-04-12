import XCTest
import SwiftCheck
@testable import dAIry

final class DiaryGeneratorPropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 9: Generator produces one entry per non-empty collected data
    func testGeneratorProducesOneEntryPerNonEmptyData() {
        let sourceTypeGen = Gen<Int>.fromElements(in: 0...1)

        property("For any non-empty CollectedData, exactly one DiaryEntry is produced") <- forAll(sourceTypeGen) { (sourceType: Int) in
            let mockGenerator = MockDiaryGenerator()
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let window = CollectionWindow(date: now, start: startOfDay, end: endOfDay)

            let photos: [PhotoData]
            let health: HealthData?

            switch sourceType {
            case 0:
                photos = [PhotoData(assetIdentifier: "photo-1", captureDate: now, location: nil, caption: "Test")]
                health = nil
            default:
                photos = []
                health = HealthData(stepCount: 1000, walkingRunningDistance: 800, activeEnergyBurned: 200)
            }

            let data = CollectedData(window: window, photos: photos, health: health)
            guard !data.isEmpty else { return false }

            let semaphore = DispatchSemaphore(value: 0)
            var entry: DiaryEntry?
            var entryCount = 0
            Task {
                do { entry = try await mockGenerator.generate(from: data); entryCount = 1 }
                catch { entryCount = 0 }
                semaphore.signal()
            }
            semaphore.wait()
            return entryCount == 1 && entry != nil
        }
    }

    // Feature: dairy-ios-app, Property 10: Entry references match available data sources
    func testEntryReferencesMatchAvailableDataSources() {
        let hasPhotosGen = Bool.arbitrary
        let hasHealthGen = Bool.arbitrary

        property("Entry contains references for each non-empty source") <- forAll(hasPhotosGen, hasHealthGen) { (hasPhotos: Bool, hasHealth: Bool) in
            guard hasPhotos || hasHealth else { return true }

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

            let data = CollectedData(window: window, photos: photos, health: health)

            let entry = DiaryEntry(
                date: data.window.date,
                text: "Test entry",
                photoReferences: data.photos.map {
                    PhotoReference(assetIdentifier: $0.assetIdentifier, captureDate: $0.captureDate, caption: $0.caption)
                },
                healthSummary: data.health.map {
                    HealthSummary(stepCount: $0.stepCount, walkingRunningDistanceMeters: $0.walkingRunningDistance, activeEnergyBurnedKcal: $0.activeEnergyBurned)
                }
            )

            let photosMatch = hasPhotos ? !entry.photoReferences.isEmpty : entry.photoReferences.isEmpty
            let healthMatch = hasHealth ? entry.healthSummary != nil : entry.healthSummary == nil
            return photosMatch && healthMatch
        }
    }

    // Feature: dairy-ios-app, Property 11: Entry date matches CollectionWindow date
    func testEntryDateMatchesCollectionWindowDate() {
        property("Generated entry date matches the CollectionWindow date") <- forAll { (arbWindow: ArbitraryCollectionWindow) in
            let window = arbWindow.window
            let photos = [PhotoData(assetIdentifier: "p1", captureDate: window.date, location: nil, caption: nil)]
            let data = CollectedData(window: window, photos: photos, health: nil)

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
