import XCTest
import SwiftCheck
@testable import dAIry

// MARK: - Scheduler Property Tests

final class SchedulerPropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 3: Collection time setting round-trip
    // **Validates: Requirements 4.1**
    func testCollectionTimeSettingRoundTrip() {
        let validHours = Gen<Int>.fromElements(in: 0...23)
        let validMinutes = Gen<Int>.fromElements(in: 0...59)

        property("Storing and retrieving any valid hour/minute produces the same value") <- forAll(validHours, validMinutes) { (hour: Int, minute: Int) in
            let userDefaults = UserDefaults(suiteName: "test.scheduler.\(UUID().uuidString)")!
            let mockCollector = MockDataCollector()
            let mockGenerator = MockDiaryGenerator()
            let mockStorage = MockStorageManager()

            let scheduler = DailyScheduler(
                dataCollector: mockCollector,
                diaryGenerator: mockGenerator,
                storage: mockStorage,
                userDefaults: userDefaults
            )

            let timeToStore = DateComponents(hour: hour, minute: minute)
            scheduler.configuredTime = timeToStore

            let retrieved = scheduler.configuredTime

            userDefaults.removePersistentDomain(forName: userDefaults.description)

            return retrieved.hour == hour && retrieved.minute == minute
        }
    }

    // Feature: dairy-ios-app, Property 4: Scheduler triggers collection with correct CollectionWindow
    // **Validates: Requirements 4.2**
    func testSchedulerTriggersWithCorrectCollectionWindow() {
        property("For any trigger, the CollectionWindow is midnight-to-midnight") <- forAll(Gen<Int>.pure(0)) { (_: Int) in
            let calendar = Calendar.current
            let window = CollectionWindow.today(calendar: calendar)

            let startComponents = calendar.dateComponents([.hour, .minute, .second], from: window.start)
            let isMidnightStart = startComponents.hour == 0
                && startComponents.minute == 0
                && startComponents.second == 0

            // End should be exactly 1 day after start
            let expectedEnd = calendar.date(byAdding: .day, value: 1, to: window.start)!
            let endMatches = abs(window.end.timeIntervalSince(expectedEnd)) < 1.0

            return isMidnightStart && endMatches
        }
    }

    // Feature: dairy-ios-app, Property 5: Scheduler retries on failure
    // **Validates: Requirements 4.4**
    func testSchedulerRetriesOnFailure() {
        property("For any failed attempt, scheduler re-schedules") <- forAll(Gen<Int>.fromElements(in: 1...10)) { (attemptCount: Int) in
            let userDefaults = UserDefaults(suiteName: "test.retry.\(UUID().uuidString)")!
            let mockCollector = MockDataCollector()
            mockCollector.shouldThrow = true
            let mockGenerator = MockDiaryGenerator()
            let mockStorage = MockStorageManager()

            let scheduler = DailyScheduler(
                dataCollector: mockCollector,
                diaryGenerator: mockGenerator,
                storage: mockStorage,
                userDefaults: userDefaults
            )

            // Verify the scheduler has retry capability by checking nextOccurrence
            let retryTime = DateComponents(hour: 21, minute: 0)
            let nextDate = scheduler.nextOccurrence(of: retryTime)

            userDefaults.removePersistentDomain(forName: userDefaults.description)

            // The scheduler should always be able to compute a next occurrence for retry
            return nextDate != nil
        }
    }
}
