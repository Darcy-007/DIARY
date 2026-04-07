import Testing
import Foundation
@testable import dAIry

// Task 12.5: Test DiaryGenerator — prompt construction, empty data handling, date association
// Task 12.9: Test DiaryGenerator API key gate — generation blocked without key, proceeds with valid key

@Suite("DiaryGenerator Tests")
struct DiaryGeneratorTests {

    // MARK: - Helper

    private func makeWindow() -> CollectionWindow {
        CollectionWindow.today()
    }

    // MARK: - 12.5: Prompt Construction

    @Test("buildPrompt includes photo count")
    func promptIncludesPhotoCount() {
        let apiKeyManager = MockAPIKeyManager()
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let photos = [
            PhotoData(assetIdentifier: "p1", captureDate: Date(), location: nil, caption: nil),
            PhotoData(assetIdentifier: "p2", captureDate: Date(), location: nil, caption: "Beach")
        ]
        let data = CollectedData(window: window, photos: photos, health: nil, transactions: [])
        let prompt = generator.buildPrompt(from: data)
        #expect(prompt.contains("2 photos"))
    }

    @Test("buildPrompt includes health data")
    func promptIncludesHealthData() {
        let apiKeyManager = MockAPIKeyManager()
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let health = HealthData(stepCount: 8000, walkingRunningDistance: 6000, activeEnergyBurned: 300)
        let data = CollectedData(window: window, photos: [], health: health, transactions: [])
        let prompt = generator.buildPrompt(from: data)
        #expect(prompt.contains("8000 steps"))
        #expect(prompt.contains("300 kcal"))
    }

    @Test("buildPrompt includes transaction details")
    func promptIncludesTransactions() {
        let apiKeyManager = MockAPIKeyManager()
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let txs = [
            TransactionData(merchantName: "Starbucks", amount: 5.50, date: Date())
        ]
        let data = CollectedData(window: window, photos: [], health: nil, transactions: txs)
        let prompt = generator.buildPrompt(from: data)
        #expect(prompt.contains("1 transactions"))
        #expect(prompt.contains("Starbucks"))
    }

    @Test("buildPrompt includes photo caption when present")
    func promptIncludesCaption() {
        let apiKeyManager = MockAPIKeyManager()
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let photos = [
            PhotoData(assetIdentifier: "p1", captureDate: Date(), location: nil, caption: "Sunset view")
        ]
        let data = CollectedData(window: window, photos: photos, health: nil, transactions: [])
        let prompt = generator.buildPrompt(from: data)
        #expect(prompt.contains("Sunset view"))
    }

    @Test("buildPrompt ends with diary instruction")
    func promptEndWithInstruction() {
        let apiKeyManager = MockAPIKeyManager()
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let health = HealthData(stepCount: 100, walkingRunningDistance: 50, activeEnergyBurned: 10)
        let data = CollectedData(window: window, photos: [], health: health, transactions: [])
        let prompt = generator.buildPrompt(from: data)
        #expect(prompt.contains("Write a first-person diary entry"))
    }

    // MARK: - 12.5: Empty Data Handling

    @Test("generate throws noDataAvailable for empty data")
    func generateThrowsForEmptyData() async {
        let apiKeyManager = MockAPIKeyManager()
        apiKeyManager.storedKey = "test-key"
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let data = CollectedData(window: window, photos: [], health: nil, transactions: [])

        do {
            _ = try await generator.generate(from: data)
            #expect(Bool(false), "Should have thrown")
        } catch let error as DiaryGeneratorError {
            #expect(error == .noDataAvailable)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    // MARK: - 12.5: Date Association (via mock)

    @Test("Generated entry date matches collection window date")
    func entryDateMatchesWindow() async throws {
        let mockGenerator = MockDiaryGenerator()
        let window = makeWindow()
        let health = HealthData(stepCount: 100, walkingRunningDistance: 50, activeEnergyBurned: 10)
        let data = CollectedData(window: window, photos: [], health: health, transactions: [])
        let entry = try await mockGenerator.generate(from: data)
        #expect(entry.date == window.date)
    }

    // MARK: - 12.9: API Key Gate

    @Test("generate throws apiKeyNotConfigured when no key")
    func generateBlockedWithoutKey() async {
        let apiKeyManager = MockAPIKeyManager()
        // No key stored
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let health = HealthData(stepCount: 100, walkingRunningDistance: 50, activeEnergyBurned: 10)
        let data = CollectedData(window: window, photos: [], health: health, transactions: [])

        do {
            _ = try await generator.generate(from: data)
            #expect(Bool(false), "Should have thrown")
        } catch let error as DiaryGeneratorError {
            #expect(error == .apiKeyNotConfigured)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("generate proceeds past key gate with valid key")
    func generateProceedsWithValidKey() async {
        let apiKeyManager = MockAPIKeyManager()
        apiKeyManager.storedKey = "valid-key-123"
        let generator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let window = makeWindow()
        let health = HealthData(stepCount: 100, walkingRunningDistance: 50, activeEnergyBurned: 10)
        let data = CollectedData(window: window, photos: [], health: health, transactions: [])

        // This will fail at the network call (no real API), but it should NOT throw apiKeyNotConfigured
        do {
            _ = try await generator.generate(from: data)
            #expect(Bool(false), "Should have thrown a network error")
        } catch let error as DiaryGeneratorError {
            // Should be a network error, NOT apiKeyNotConfigured
            switch error {
            case .apiKeyNotConfigured:
                #expect(Bool(false), "Should not be apiKeyNotConfigured")
            default:
                // Any other error means we passed the key gate
                #expect(true)
            }
        } catch {
            // Network errors are expected — key gate was passed
            #expect(true)
        }
    }
}
