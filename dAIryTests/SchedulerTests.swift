import Testing
import Foundation
@testable import dAIry

// Task 12.7: Test Scheduler — default time, custom time persistence, retry scheduling

@Suite("Scheduler Tests")
struct SchedulerTests {

    // MARK: - Helper

    private func makeScheduler(defaults: UserDefaults? = nil) -> DailyScheduler {
        let ud = defaults ?? UserDefaults(suiteName: "test.scheduler.\(UUID().uuidString)")!
        let collector = MockDataCollector()
        let generator = MockDiaryGenerator()
        let storage = MockStorageManager()
        return DailyScheduler(
            dataCollector: collector,
            diaryGenerator: generator,
            storage: storage,
            userDefaults: ud
        )
    }

    // MARK: - Default Time

    @Test("Default configured time is 21:00")
    func defaultTimeIs2100() {
        let scheduler = makeScheduler()
        let time = scheduler.configuredTime
        #expect(time.hour == 21)
        #expect(time.minute == 0)
    }

    // MARK: - Custom Time Persistence

    @Test("Custom time persists after setting")
    func customTimePersists() {
        let suiteName = "test.scheduler.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let scheduler = makeScheduler(defaults: defaults)
        scheduler.scheduleDailyCollection(at: DateComponents(hour: 8, minute: 30))
        let time = scheduler.configuredTime
        #expect(time.hour == 8)
        #expect(time.minute == 30)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Custom time survives re-creation with same defaults")
    func customTimeSurvivesRecreation() {
        let suiteName = "test.scheduler.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let scheduler1 = DailyScheduler(
            dataCollector: MockDataCollector(),
            diaryGenerator: MockDiaryGenerator(),
            storage: MockStorageManager(),
            userDefaults: defaults
        )
        scheduler1.scheduleDailyCollection(at: DateComponents(hour: 7, minute: 15))

        let scheduler2 = DailyScheduler(
            dataCollector: MockDataCollector(),
            diaryGenerator: MockDiaryGenerator(),
            storage: MockStorageManager(),
            userDefaults: defaults
        )
        #expect(scheduler2.configuredTime.hour == 7)
        #expect(scheduler2.configuredTime.minute == 15)
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Next Occurrence

    @Test("nextOccurrence returns a future date")
    func nextOccurrenceIsFuture() {
        let scheduler = makeScheduler()
        let time = DateComponents(hour: 21, minute: 0)
        let next = scheduler.nextOccurrence(of: time)
        #expect(next != nil)
        #expect(next! > Date())
    }

    @Test("nextOccurrence matches requested hour and minute")
    func nextOccurrenceMatchesTime() {
        let scheduler = makeScheduler()
        let time = DateComponents(hour: 14, minute: 30)
        let next = scheduler.nextOccurrence(of: time)
        #expect(next != nil)
        let components = Calendar.current.dateComponents([.hour, .minute], from: next!)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }

    // MARK: - Task Identifier

    @Test("Task identifier is correct")
    func taskIdentifier() {
        #expect(DailyScheduler.taskIdentifier == "com.dairy.dailyCollection")
    }
}
