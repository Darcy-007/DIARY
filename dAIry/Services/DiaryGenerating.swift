import Foundation

protocol DiaryGenerating {
    func generate(from data: CollectedData) async throws -> DiaryEntry
}
