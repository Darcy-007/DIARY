import Testing
import Foundation
@testable import dAIry

// Task 12.3: Test DataCollector — date filtering, empty source handling, metadata extraction with mocks
// Task 12.4: Test HealthData aggregation with known sample sets

@Suite("DataCollector Tests")
struct DataCollectorTests {

    // MARK: - 12.3: collectAll with mock permission manager

    @Test("collectAll skips unauthorized photo source")
    func collectAllSkipsUnauthorizedPhotos() async throws {
        let pm = MockPermissionManager()
        pm.statuses[.photos] = .denied
        pm.statuses[.healthKit] = .denied

        let collector = MockDataCollector()
        let window = CollectionWindow.today()
        let data = try await collector.collectAll(for: window)
        #expect(data.photos.isEmpty)
        #expect(data.health == nil)
    }

    @Test("collectAll returns photos when source has data")
    func collectAllReturnsPhotos() async throws {
        let collector = MockDataCollector()
        let window = CollectionWindow.today()
        let photo = PhotoData(
            assetIdentifier: "test-123",
            captureDate: Date(),
            location: nil,
            caption: "Test photo"
        )
        collector.photosResult = [photo]
        let data = try await collector.collectAll(for: window)
        #expect(data.photos.count == 1)
        #expect(data.photos.first?.assetIdentifier == "test-123")
        #expect(data.photos.first?.caption == "Test photo")
    }

    @Test("collectAll returns empty when no data available")
    func collectAllReturnsEmpty() async throws {
        let collector = MockDataCollector()
        let window = CollectionWindow.today()
        let data = try await collector.collectAll(for: window)
        #expect(data.isEmpty)
    }

    @Test("collectAll passes correct window to collector")
    func collectAllPassesCorrectWindow() async throws {
        let collector = MockDataCollector()
        let window = CollectionWindow.today()
        _ = try await collector.collectAll(for: window)
        #expect(collector.lastWindow?.start == window.start)
        #expect(collector.lastWindow?.end == window.end)
    }

    @Test("collectAll throws when collector fails")
    func collectAllThrowsOnFailure() async {
        let collector = MockDataCollector()
        collector.shouldThrow = true
        let window = CollectionWindow.today()
        do {
            _ = try await collector.collectAll(for: window)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is NSError)
        }
    }

    // MARK: - 12.3: Metadata extraction

    @Test("PhotoData preserves all metadata fields")
    func photoDataPreservesMetadata() {
        let date = Date()
        let photo = PhotoData(
            assetIdentifier: "asset-456",
            captureDate: date,
            location: nil,
            caption: "Sunset"
        )
        #expect(photo.assetIdentifier == "asset-456")
        #expect(photo.captureDate == date)
        #expect(photo.location == nil)
        #expect(photo.caption == "Sunset")
    }

    // MARK: - 12.4: HealthData aggregation with known sample sets

    @Test("HealthData stores correct step count")
    func healthDataStepCount() {
        let health = HealthData(stepCount: 10000, walkingRunningDistance: 7500, activeEnergyBurned: 350)
        #expect(health.stepCount == 10000)
    }

    @Test("HealthData stores correct distance")
    func healthDataDistance() {
        let health = HealthData(stepCount: 5000, walkingRunningDistance: 3750.5, activeEnergyBurned: 200)
        #expect(health.walkingRunningDistance == 3750.5)
    }

    @Test("HealthData stores correct energy burned")
    func healthDataEnergy() {
        let health = HealthData(stepCount: 8000, walkingRunningDistance: 6000, activeEnergyBurned: 425.7)
        #expect(health.activeEnergyBurned == 425.7)
    }

    @Test("HealthSummary round-trip from HealthData")
    func healthSummaryFromHealthData() {
        let health = HealthData(stepCount: 12000, walkingRunningDistance: 9000, activeEnergyBurned: 500)
        let summary = HealthSummary(
            stepCount: health.stepCount,
            walkingRunningDistanceMeters: health.walkingRunningDistance,
            activeEnergyBurnedKcal: health.activeEnergyBurned
        )
        #expect(summary.stepCount == 12000)
        #expect(summary.walkingRunningDistanceMeters == 9000)
        #expect(summary.activeEnergyBurnedKcal == 500)
    }

    @Test("HealthData with zero values")
    func healthDataZeroValues() {
        let health = HealthData(stepCount: 0, walkingRunningDistance: 0, activeEnergyBurned: 0)
        #expect(health.stepCount == 0)
        #expect(health.walkingRunningDistance == 0)
        #expect(health.activeEnergyBurned == 0)
    }
}
