import Foundation

protocol StorageManaging {
    func save(_ entry: DiaryEntry) throws
    func fetchAll() -> [DiaryEntry]
    func fetch(for date: Date) -> DiaryEntry?
    func delete(_ entry: DiaryEntry) throws
    func entryExists(for date: Date) -> Bool
}
