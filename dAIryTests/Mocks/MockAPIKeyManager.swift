import Foundation
@testable import dAIry

final class MockAPIKeyManager: APIKeyManaging {
    var storedKey: String?
    var validationResult: APIKeyValidationResult = .valid
    var shouldThrowOnSave = false
    var shouldThrowOnDelete = false

    func saveKey(_ key: String) async throws -> APIKeyValidationResult {
        if shouldThrowOnSave { throw NSError(domain: "MockAPIKey", code: 1) }
        let result = await validateKey(key)
        switch result {
        case .valid:
            storedKey = key
        case .invalid, .networkError:
            break
        }
        return result
    }

    func getKey() -> String? {
        storedKey
    }

    func deleteKey() throws {
        if shouldThrowOnDelete { throw NSError(domain: "MockAPIKey", code: 2) }
        storedKey = nil
    }

    func isKeyConfigured() -> Bool {
        storedKey != nil
    }

    func validateKey(_ key: String) async -> APIKeyValidationResult {
        validationResult
    }
}
