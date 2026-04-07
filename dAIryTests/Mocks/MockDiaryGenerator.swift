import Foundation
@testable import dAIry

final class MockDiaryGenerator: DiaryGenerating {
    var generateResult: DiaryEntry?
    var shouldThrow = false
    var errorToThrow: Error = DiaryGeneratorError.noDataAvailable
    var lastData: CollectedData?

    func generate(from data: CollectedData) async throws -> DiaryEntry {
        lastData = data
        if shouldThrow { throw errorToThrow }
        if let result = generateResult { return result }
        return DiaryEntry(
            date: data.window.date,
            text: "Mock diary entry"
        )
    }
}
