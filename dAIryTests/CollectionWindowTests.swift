import Testing
import Foundation
@testable import dAIry

// Task 12.2: Test CollectionWindow — today() at various times and time zones, midnight boundaries

@Suite("CollectionWindow Tests")
struct CollectionWindowTests {

    @Test("today() start is midnight of current day")
    func todayStartIsMidnight() {
        let calendar = Calendar.current
        let window = CollectionWindow.today(calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute, .second], from: window.start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("today() end is exactly 24 hours after start")
    func todayEndIs24HoursAfterStart() {
        let window = CollectionWindow.today()
        let interval = window.end.timeIntervalSince(window.start)
        #expect(interval == 86400)
    }

    @Test("today() start and end are on consecutive days")
    func startAndEndConsecutiveDays() {
        let calendar = Calendar.current
        let window = CollectionWindow.today(calendar: calendar)
        // end is start of next day
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: window.start)!
        #expect(window.end == expectedEnd)
    }

    @Test("today() with specific timezone (UTC)")
    func todayWithUTC() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let window = CollectionWindow.today(calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute, .second], from: window.start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("today() with Pacific timezone")
    func todayWithPacific() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let window = CollectionWindow.today(calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute, .second], from: window.start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test("today() with Tokyo timezone")
    func todayWithTokyo() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let window = CollectionWindow.today(calendar: calendar)
        let interval = window.end.timeIntervalSince(window.start)
        #expect(interval == 86400)
    }

    @Test("CollectedData isEmpty when all sources empty")
    func collectedDataIsEmpty() {
        let window = CollectionWindow.today()
        let data = CollectedData(window: window, photos: [], health: nil, transactions: [])
        #expect(data.isEmpty)
    }

    @Test("CollectedData is not empty with health data")
    func collectedDataNotEmptyWithHealth() {
        let window = CollectionWindow.today()
        let health = HealthData(stepCount: 100, walkingRunningDistance: 50, activeEnergyBurned: 10)
        let data = CollectedData(window: window, photos: [], health: health, transactions: [])
        #expect(!data.isEmpty)
    }
}
