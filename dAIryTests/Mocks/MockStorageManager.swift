import Foundation
@testable import dAIry

final class MockStorageManager: StorageManaging {
    var entries: [DiaryEntry] = []
    var shouldThrow = false

    func save(_ entry: DiaryEntry) throws {
        if shouldThrow { throw NSError(domain: "MockStorage", code: 1) }
        entries.append(entry)
    }

    func fetchAll() -> [DiaryEntry] {
        entries.sorted { $0.date > $1.date }
    }

    func fetch(for date: Date) -> DiaryEntry? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return entries.first { $0.date >= startOfDay && $0.date < endOfDay }
    }

    func delete(_ entry: DiaryEntry) throws {
        if shouldThrow { throw NSError(domain: "MockStorage", code: 2) }
        entries.removeAll { $0.id == entry.id }
    }

    func entryExists(for date: Date) -> Bool {
        fetch(for: date) != nil
    }
}
