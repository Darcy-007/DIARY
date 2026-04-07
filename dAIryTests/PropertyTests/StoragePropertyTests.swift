import XCTest
import SwiftCheck
@testable import dAIry

// MARK: - Storage Property Tests

final class StoragePropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 12: Existing entry conflict detection
    // **Validates: Requirements 9.5**
    func testExistingEntryConflictDetection() {
        let daysAgoGen = Gen<Int>.fromElements(in: 0...364)

        property("For any date with existing entry, entryExists returns true") <- forAll(daysAgoGen) { (daysAgo: Int) in
            let storage = MockStorageManager()
            let calendar = Calendar.current
            let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            let startOfDay = calendar.startOfDay(for: targetDate)

            // Save an entry for that date
            let entry = DiaryEntry(
                date: startOfDay,
                text: "Existing entry for day \(daysAgo)"
            )
            try? storage.save(entry)

            // Conflict detection should find the existing entry
            let conflictDetected = storage.entryExists(for: startOfDay)

            return conflictDetected
        }
    }

    // Feature: dairy-ios-app, Property 13: DiaryEntry save/fetch round-trip
    // **Validates: Requirements 10.1**
    func testDiaryEntrySaveFetchRoundTrip() {
        let textGen = Gen<String>.compose { c in
            "Diary entry text \(c.generate(using: Gen<Int>.fromElements(in: 1...99999)))"
        }
        let daysAgoGen = Gen<Int>.fromElements(in: 0...364)
        let isSupplementalGen = Bool.arbitrary

        property("Save then fetch returns identical data") <- forAll(textGen, daysAgoGen, isSupplementalGen) { (text: String, daysAgo: Int, isSupplemental: Bool) in
            let storage = MockStorageManager()
            let calendar = Calendar.current
            let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            let startOfDay = calendar.startOfDay(for: targetDate)

            let entry = DiaryEntry(
                date: startOfDay,
                text: text,
                photoReferences: [PhotoReference(assetIdentifier: "asset-1", captureDate: startOfDay, caption: "cap")],
                healthSummary: HealthSummary(stepCount: 1000, walkingRunningDistanceMeters: 800, activeEnergyBurnedKcal: 200),
                transactionSummary: [TransactionSummary(merchantName: "Store", amount: 42.50, date: startOfDay)],
                isSupplemental: isSupplemental
            )

            try? storage.save(entry)
            let fetched = storage.fetch(for: startOfDay)

            guard let fetched = fetched else { return false }

            let idMatch = fetched.id == entry.id
            let dateMatch = fetched.date == entry.date
            let textMatch = fetched.text == entry.text
            let photoMatch = fetched.photoReferences.count == entry.photoReferences.count
            let healthMatch = fetched.healthSummary?.stepCount == entry.healthSummary?.stepCount
            let txMatch = fetched.transactionSummary.count == entry.transactionSummary.count
            let supplementalMatch = fetched.isSupplemental == entry.isSupplemental

            return idMatch && dateMatch && textMatch && photoMatch && healthMatch && txMatch && supplementalMatch
        }
    }

    // Feature: dairy-ios-app, Property 14: Diary entries sorted chronologically
    // **Validates: Requirements 10.2**
    func testDiaryEntriesSortedChronologically() {
        let entryCountGen = Gen<Int>.fromElements(in: 2...15)

        property("fetchAll returns entries in descending date order") <- forAll(entryCountGen) { (count: Int) in
            let storage = MockStorageManager()
            let calendar = Calendar.current

            // Create entries with different dates in random order
            var dates: [Date] = []
            for i in 0..<count {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                dates.append(calendar.startOfDay(for: date))
            }
            dates.shuffle()

            for (index, date) in dates.enumerated() {
                let entry = DiaryEntry(date: date, text: "Entry \(index)")
                try? storage.save(entry)
            }

            let fetched = storage.fetchAll()

            // Verify descending order
            guard fetched.count == count else { return false }

            for i in 0..<(fetched.count - 1) {
                if fetched[i].date < fetched[i + 1].date {
                    return false
                }
            }

            return true
        }
    }

    // Feature: dairy-ios-app, Property 15: Delete removes entry from storage
    // **Validates: Requirements 10.4**
    func testDeleteRemovesEntryFromStorage() {
        let entryCountGen = Gen<Int>.fromElements(in: 1...10)

        property("After deletion, entry is gone and count decreases by one") <- forAll(entryCountGen) { (count: Int) in
            let storage = MockStorageManager()
            let calendar = Calendar.current

            // Create entries
            var entries: [DiaryEntry] = []
            for i in 0..<count {
                let date = calendar.date(byAdding: .day, value: -i, to: Date())!
                let entry = DiaryEntry(date: calendar.startOfDay(for: date), text: "Entry \(i)")
                try? storage.save(entry)
                entries.append(entry)
            }

            let countBefore = storage.fetchAll().count

            // Delete a random entry
            let indexToDelete = Int.random(in: 0..<entries.count)
            let entryToDelete = entries[indexToDelete]
            try? storage.delete(entryToDelete)

            let countAfter = storage.fetchAll().count
            let fetchedAfterDelete = storage.fetch(for: entryToDelete.date)

            let countDecreased = countAfter == countBefore - 1
            let entryGone = fetchedAfterDelete == nil

            return countDecreased && entryGone
        }
    }
}
