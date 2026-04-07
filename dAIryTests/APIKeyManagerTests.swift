import Testing
import Foundation
@testable import dAIry

// Task 12.8: Test APIKeyManager — save/retrieve/delete cycle, validation with mock Gemini responses,
//            isKeyConfigured() state transitions

@Suite("APIKeyManager Tests")
struct APIKeyManagerTests {

    // MARK: - Save / Retrieve / Delete Cycle

    @Test("Save valid key, retrieve it, then delete")
    func saveRetrieveDeleteCycle() async throws {
        let manager = MockAPIKeyManager()
        manager.validationResult = .valid

        let result = try await manager.saveKey("test-api-key-123")
        #expect(result == .valid)
        #expect(manager.getKey() == "test-api-key-123")

        try manager.deleteKey()
        #expect(manager.getKey() == nil)
    }

    @Test("Save stores key only when valid")
    func saveStoresOnlyWhenValid() async throws {
        let manager = MockAPIKeyManager()
        manager.validationResult = .invalid(reason: "Bad key")

        let result = try await manager.saveKey("bad-key")
        switch result {
        case .invalid(let reason):
            #expect(reason == "Bad key")
        default:
            #expect(Bool(false), "Expected invalid result")
        }
        #expect(manager.getKey() == nil)
    }

    // MARK: - Validation with Mock Responses

    @Test("Validation returns valid for good key")
    func validationReturnsValid() async {
        let manager = MockAPIKeyManager()
        manager.validationResult = .valid
        let result = await manager.validateKey("good-key")
        #expect(result == .valid)
    }

    @Test("Validation returns invalid for bad key")
    func validationReturnsInvalid() async {
        let manager = MockAPIKeyManager()
        manager.validationResult = .invalid(reason: "Invalid API key")
        let result = await manager.validateKey("bad-key")
        switch result {
        case .invalid(let reason):
            #expect(reason == "Invalid API key")
        default:
            #expect(Bool(false), "Expected invalid result")
        }
    }

    @Test("Validation returns networkError on failure")
    func validationReturnsNetworkError() async {
        let manager = MockAPIKeyManager()
        let error = NSError(domain: "Network", code: -1009)
        manager.validationResult = .networkError(error)
        let result = await manager.validateKey("any-key")
        switch result {
        case .networkError:
            #expect(true)
        default:
            #expect(Bool(false), "Expected networkError result")
        }
    }

    @Test("Network error does not store key")
    func networkErrorDoesNotStoreKey() async throws {
        let manager = MockAPIKeyManager()
        manager.validationResult = .networkError(NSError(domain: "Net", code: -1))
        _ = try await manager.saveKey("some-key")
        #expect(manager.getKey() == nil)
    }

    // MARK: - isKeyConfigured() State Transitions

    @Test("isKeyConfigured false initially")
    func isKeyConfiguredFalseInitially() {
        let manager = MockAPIKeyManager()
        #expect(!manager.isKeyConfigured())
    }

    @Test("isKeyConfigured true after saving valid key")
    func isKeyConfiguredTrueAfterSave() async throws {
        let manager = MockAPIKeyManager()
        manager.validationResult = .valid
        _ = try await manager.saveKey("valid-key")
        #expect(manager.isKeyConfigured())
    }

    @Test("isKeyConfigured false after deleting key")
    func isKeyConfiguredFalseAfterDelete() async throws {
        let manager = MockAPIKeyManager()
        manager.validationResult = .valid
        _ = try await manager.saveKey("valid-key")
        #expect(manager.isKeyConfigured())
        try manager.deleteKey()
        #expect(!manager.isKeyConfigured())
    }

    @Test("isKeyConfigured false after saving invalid key")
    func isKeyConfiguredFalseAfterInvalidSave() async throws {
        let manager = MockAPIKeyManager()
        manager.validationResult = .invalid(reason: "Nope")
        _ = try await manager.saveKey("bad-key")
        #expect(!manager.isKeyConfigured())
    }
}
