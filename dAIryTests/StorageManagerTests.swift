import Testing
import Foundation
import SwiftData
@testable import dAIry

// Task 12.6: Test StorageManager — CRUD, duplicate date conflict, chronological ordering

@Suite("StorageManager Tests")
struct StorageManagerTests {

    // MARK: - Helper

    private func makeInMemoryStorage() throws -> StorageManager {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DiaryEntry.self, configurations: config)
        let context = ModelContext(container)
        return StorageManager(modelContext: context)
    }

    // MARK: - CRUD

    @Test("Save and fetch entry")
    func saveAndFetch() throws {
        let storage = try makeInMemoryStorage()
        let entry = DiaryEntry(date: Date(), text: "Today was great")
        try storage.save(entry)
        let all = storage.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.text == "Today was great")
    }

    @Test("Fetch by date returns correct entry")
    func fetchByDate() throws {
        let storage = try makeInMemoryStorage()
        let date = Date()
        let entry = DiaryEntry(date: date, text: "Specific day entry")
        try storage.save(entry)
        let fetched = storage.fetch(for: date)
        #expect(fetched != nil)
        #expect(fetched?.text == "Specific day entry")
    }

    @Test("Fetch by date returns nil for missing date")
    func fetchByDateMissing() throws {
        let storage = try makeInMemoryStorage()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let fetched = storage.fetch(for: yesterday)
        #expect(fetched == nil)
    }

    @Test("Delete removes entry")
    func deleteEntry() throws {
        let storage = try makeInMemoryStorage()
        let entry = DiaryEntry(date: Date(), text: "To be deleted")
        try storage.save(entry)
        #expect(storage.fetchAll().count == 1)
        try storage.delete(entry)
        #expect(storage.fetchAll().count == 0)
    }

    // MARK: - Duplicate Date Conflict

    @Test("entryExists returns true for existing date")
    func entryExistsTrue() throws {
        let storage = try makeInMemoryStorage()
        let date = Date()
        let entry = DiaryEntry(date: date, text: "Existing entry")
        try storage.save(entry)
        #expect(storage.entryExists(for: date))
    }

    @Test("entryExists returns false for missing date")
    func entryExistsFalse() throws {
        let storage = try makeInMemoryStorage()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(!storage.entryExists(for: tomorrow))
    }

    // MARK: - Chronological Ordering

    @Test("fetchAll returns entries in descending date order")
    func fetchAllDescendingOrder() throws {
        let storage = try makeInMemoryStorage()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        // Save in non-chronological order
        try storage.save(DiaryEntry(date: yesterday, text: "Yesterday"))
        try storage.save(DiaryEntry(date: today, text: "Today"))
        try storage.save(DiaryEntry(date: twoDaysAgo, text: "Two days ago"))

        let all = storage.fetchAll()
        #expect(all.count == 3)
        #expect(all[0].text == "Today")
        #expect(all[1].text == "Yesterday")
        #expect(all[2].text == "Two days ago")
    }
}
