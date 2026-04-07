import XCTest
import SwiftCheck
@testable import dAIry

// MARK: - API Key Property Tests

final class APIKeyPropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 16: Valid API key enables diary generation
    // **Validates: Requirements 12.3, 12.6**
    func testValidAPIKeyEnablesDiaryGeneration() {
        let keyGen = Gen<String>.compose { c in
            "AIzaSy\(c.generate(using: Gen<Int>.fromElements(in: 10000...99999)))"
        }

        property("For any valid key, isKeyConfigured returns true after save") <- forAll(keyGen) { (key: String) in
            let mockAPIKeyManager = MockAPIKeyManager()
            mockAPIKeyManager.validationResult = .valid

            let semaphore = DispatchSemaphore(value: 0)
            var result: APIKeyValidationResult?
            Task {
                result = try? await mockAPIKeyManager.saveKey(key)
                semaphore.signal()
            }
            semaphore.wait()

            let isConfigured = mockAPIKeyManager.isKeyConfigured()
            let isValid = result == .valid

            return isConfigured && isValid
        }
    }

    // Feature: dairy-ios-app, Property 17: Invalid API key is rejected and not stored
    // **Validates: Requirements 12.4**
    func testInvalidAPIKeyRejectedAndNotStored() {
        let keyGen = Gen<String>.compose { c in
            "invalid-key-\(c.generate(using: Gen<Int>.fromElements(in: 1...99999)))"
        }

        property("For any invalid key, it is not stored") <- forAll(keyGen) { (key: String) in
            let mockAPIKeyManager = MockAPIKeyManager()
            mockAPIKeyManager.validationResult = .invalid(reason: "Invalid key")

            let semaphore = DispatchSemaphore(value: 0)
            var result: APIKeyValidationResult?
            Task {
                result = try? await mockAPIKeyManager.saveKey(key)
                semaphore.signal()
            }
            semaphore.wait()

            let notStored = mockAPIKeyManager.getKey() == nil
            let isInvalid: Bool
            if case .invalid = result {
                isInvalid = true
            } else {
                isInvalid = false
            }

            return notStored && isInvalid
        }
    }

    // Feature: dairy-ios-app, Property 18: Missing API key blocks diary generation
    // **Validates: Requirements 12.5, 12.6**
    func testMissingAPIKeyBlocksDiaryGeneration() {
        property("Without a key, generation throws apiKeyNotConfigured") <- forAll(Gen<Int>.fromElements(in: 0...100)) { (_: Int) in
            let mockAPIKeyManager = MockAPIKeyManager()
            // Ensure no key is stored
            mockAPIKeyManager.storedKey = nil

            let notConfigured = !mockAPIKeyManager.isKeyConfigured()

            // DiaryGenerator should refuse to generate
            let generator = DiaryGenerator(apiKeyManager: mockAPIKeyManager)

            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let window = CollectionWindow(date: now, start: startOfDay, end: endOfDay)
            let data = CollectedData(
                window: window,
                photos: [PhotoData(assetIdentifier: "p1", captureDate: now, location: nil, caption: nil)],
                health: nil,
                transactions: []
            )

            let semaphore = DispatchSemaphore(value: 0)
            var threwCorrectError = false
            Task {
                do {
                    _ = try await generator.generate(from: data)
                } catch let error as DiaryGeneratorError {
                    threwCorrectError = error == .apiKeyNotConfigured
                } catch {
                    threwCorrectError = false
                }
                semaphore.signal()
            }
            semaphore.wait()

            return notConfigured && threwCorrectError
        }
    }

    // Feature: dairy-ios-app, Property 19: API key Keychain round-trip
    // **Validates: Requirements 12.7**
    func testAPIKeyKeychainRoundTrip() {
        let keyGen = Gen<String>.compose { c in
            "AIzaSy\(c.generate(using: Gen<Int>.fromElements(in: 10000...99999)))"
        }

        property("For any key string, save then get returns the same string") <- forAll(keyGen) { (key: String) in
            let mockAPIKeyManager = MockAPIKeyManager()
            mockAPIKeyManager.validationResult = .valid

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                _ = try? await mockAPIKeyManager.saveKey(key)
                semaphore.signal()
            }
            semaphore.wait()

            let retrieved = mockAPIKeyManager.getKey()
            return retrieved == key
        }
    }

    // Feature: dairy-ios-app, Property 20: API key deletion clears Keychain
    // **Validates: Requirements 12.8**
    func testAPIKeyDeletionClearsKeychain() {
        let keyGen = Gen<String>.compose { c in
            "AIzaSy\(c.generate(using: Gen<Int>.fromElements(in: 10000...99999)))"
        }

        property("For any stored key, delete makes getKey return nil") <- forAll(keyGen) { (key: String) in
            let mockAPIKeyManager = MockAPIKeyManager()
            mockAPIKeyManager.validationResult = .valid

            // Save the key
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                _ = try? await mockAPIKeyManager.saveKey(key)
                semaphore.signal()
            }
            semaphore.wait()

            // Verify it's stored
            let storedBefore = mockAPIKeyManager.getKey() == key
            let configuredBefore = mockAPIKeyManager.isKeyConfigured()

            // Delete the key
            try? mockAPIKeyManager.deleteKey()

            let keyAfterDelete = mockAPIKeyManager.getKey()
            let configuredAfter = mockAPIKeyManager.isKeyConfigured()

            return storedBefore && configuredBefore && keyAfterDelete == nil && !configuredAfter
        }
    }
}
