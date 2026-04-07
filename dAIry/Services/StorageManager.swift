import Foundation
import SwiftData

final class StorageManager: StorageManaging {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ entry: DiaryEntry) throws {
        modelContext.insert(entry)
        try modelContext.save()
    }

    func fetchAll() -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetch(for date: Date) -> DiaryEntry? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = #Predicate<DiaryEntry> { entry in
            entry.date >= startOfDay && entry.date < startOfNextDay
        }
        var descriptor = FetchDescriptor<DiaryEntry>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func delete(_ entry: DiaryEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }

    func entryExists(for date: Date) -> Bool {
        return fetch(for: date) != nil
    }
}
