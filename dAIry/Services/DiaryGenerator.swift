import Foundation
import GoogleGenerativeAI

// MARK: - Errors

enum DiaryGeneratorError: Error, LocalizedError, Equatable {
    case apiKeyNotConfigured
    case noDataAvailable
    case networkError(Error)
    case invalidResponse
    case emptyResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "No valid Gemini API key is configured. Please add your API key in Settings."
        case .noDataAvailable:
            return "No data was available for today."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the Gemini API."
        case .emptyResponse:
            return "The Gemini API returned an empty response."
        case .apiError(let statusCode, let message):
            return "Gemini API error (status \(statusCode)): \(message)"
        }
    }

    static func == (lhs: DiaryGeneratorError, rhs: DiaryGeneratorError) -> Bool {
        switch (lhs, rhs) {
        case (.apiKeyNotConfigured, .apiKeyNotConfigured): return true
        case (.noDataAvailable, .noDataAvailable): return true
        case (.networkError, .networkError): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.emptyResponse, .emptyResponse): return true
        case (.apiError(let l1, let l2), .apiError(let r1, let r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }
}

// MARK: - DiaryGenerator

final class DiaryGenerator: DiaryGenerating {

    private let apiKeyManager: APIKeyManaging
    private let maxRetries = 3
    /// Primary model first, fallback model second — see `GeminiModel`.
    private let modelNames = GeminiModel.names
    var language: AppLanguage = .english

    init(apiKeyManager: APIKeyManaging) {
        self.apiKeyManager = apiKeyManager
    }

    func generate(from data: CollectedData) async throws -> DiaryEntry {
        guard apiKeyManager.isKeyConfigured() else {
            throw DiaryGeneratorError.apiKeyNotConfigured
        }

        // Log collected data summary
        print("[dAIry] === Generating Diary ===")
        print("[dAIry] Photos: \(data.photos.count) (with image data: \(data.photos.filter { $0.imageData != nil }.count))")
        print("[dAIry] Health: \(data.health != nil ? "steps=\(data.health!.stepCount), dist=\(data.health!.walkingRunningDistance)m, energy=\(data.health!.activeEnergyBurned)kcal" : "nil")")
        print("[dAIry] isEmpty: \(data.isEmpty)")

        let prompt = buildPrompt(from: data)
        print("[dAIry] === Prompt ===")
        print(prompt)
        print("[dAIry] === End Prompt ===")

        let imageDataList = data.photos.compactMap { $0.imageData }
        print("[dAIry] Sending \(imageDataList.count) images to Gemini")

        let text = try await callGeminiWithRetry(prompt: prompt, images: imageDataList)
        print("[dAIry] === Gemini Response ===")
        print(text)
        print("[dAIry] === End Response ===")

        return DiaryEntry(
            date: data.window.date,
            text: text,
            photoReferences: data.photos.map {
                PhotoReference(assetIdentifier: $0.assetIdentifier, captureDate: $0.captureDate, caption: $0.caption)
            },
            healthSummary: data.health.map {
                HealthSummary(
                    stepCount: $0.stepCount,
                    walkingRunningDistanceMeters: $0.walkingRunningDistance,
                    activeEnergyBurnedKcal: $0.activeEnergyBurned
                )
            },
            locationSummary: data.locationVisits.isEmpty ? nil : LocationSummary(visits: data.locationVisits)
        )
    }

    // MARK: - Prompt Construction

    func buildPrompt(from data: CollectedData) -> String {
        var sections: [String] = []

        if data.isEmpty {
            sections.append("No photos, health data, or location data were recorded today.")
        }

        if !data.photos.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short

            let photosWithImages = data.photos.filter { $0.imageData != nil }.count
            var photoSection = "You took \(data.photos.count) photos today. \(photosWithImages) photos are attached as images — look at each one carefully to understand what was captured."
            let details = data.photos.map { photo in
                var detail = "Captured at \(formatter.string(from: photo.captureDate))"
                if let location = photo.location {
                    detail += " (location: \(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude)))"
                }
                if let caption = photo.caption, !caption.isEmpty {
                    detail += " — \"\(caption)\""
                }
                return "- " + detail
            }
            photoSection += "\n" + details.joined(separator: "\n")
            sections.append(photoSection)
        }

        if let health = data.health {
            let distanceKm = health.walkingRunningDistance / 1000.0
            sections.append(
                "You walked \(health.stepCount) steps, covered \(String(format: "%.1f", distanceKm)) km (\(Int(health.walkingRunningDistance)) meters), and burned \(Int(health.activeEnergyBurned)) kcal of active energy."
            )
        }

        if !data.locationVisits.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short

            var locSection = "You visited \(data.locationVisits.count) locations today. Use the coordinates to infer what places you might have been (e.g., home, office, restaurant, park, gym):"
            let details = data.locationVisits.map { visit in
                "- At \(formatter.string(from: visit.timestamp)): (\(String(format: "%.4f", visit.latitude)), \(String(format: "%.4f", visit.longitude)))"
            }
            locSection += "\n" + details.joined(separator: "\n")
            sections.append(locSection)
        }

        sections.append("Write a first-person diary entry for today based on this data. If no data was recorded, write a short, lighthearted entry about having a quiet uneventful day where you did nothing notable — something like \"today was not so fruitful and I literally did nothing\". \(language.geminiInstruction)")

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Gemini SDK Call with Retry

    private func callGeminiWithRetry(prompt: String, images: [Data]) async throws -> String {
        var lastError: Error = DiaryGeneratorError.networkError(
            NSError(domain: "DiaryGenerator", code: -1)
        )

        for attempt in 0..<maxRetries {
            // Attempt 0 uses the primary model; once we've fallen back, stay on the fallback
            // for any remaining attempts (index is clamped to the last entry in modelNames).
            let modelName = modelNames[min(attempt, modelNames.count - 1)]
            do {
                print("[dAIry] Gemini API attempt \(attempt + 1)/\(maxRetries) using model \(modelName)")
                return try await callGemini(prompt: prompt, images: images, modelName: modelName)
            } catch {
                print("[dAIry] Attempt \(attempt + 1) (model \(modelName)) failed: \(error)")
                lastError = error

                if attempt < maxRetries - 1 {
                    let nextModelName = modelNames[min(attempt + 1, modelNames.count - 1)]
                    if GeminiErrorClassifier.isPromptBlocked(error) {
                        print("[dAIry] Prompt blocked on \(modelName), falling back to \(nextModelName)")
                    } else if GeminiErrorClassifier.isRateLimited(error) {
                        print("[dAIry] Rate limited on \(modelName), falling back to \(nextModelName)")
                    }
                    // Longer backoff: 2s, 4s, 8s, 16s
                    let delay = UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
                    print("[dAIry] Retrying in \(Int(pow(2.0, Double(attempt + 1))))s...")
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw DiaryGeneratorError.networkError(lastError)
    }

    private func callGemini(prompt: String, images: [Data], modelName: String) async throws -> String {
        guard let apiKey = apiKeyManager.getKey() else {
            throw DiaryGeneratorError.apiKeyNotConfigured
        }

        let model = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            safetySettings: SafetySetting.permissive
        )

        // Build multimodal parts: text + images
        var parts: [any ThrowingPartsRepresentable] = [ModelContent.Part.text(prompt)]

        for jpegData in images.prefix(100) {
            parts.append(ModelContent.Part.data(mimetype: "image/jpeg", jpegData))
        }

        let response = try await model.generateContent(parts)

        guard let text = response.text, !text.isEmpty else {
            throw DiaryGeneratorError.emptyResponse
        }

        return text
    }
}
