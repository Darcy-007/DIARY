import Foundation
import GoogleGenerativeAI

// MARK: - Permissive Safety Settings

/// Shared safety configuration for all `GenerativeModel` instances in the app.
///
/// dAIry prompts combine the user's own private photos, precise GPS coordinates, and health
/// data. Gemini's default safety filters can block these legitimate personal prompts (observed
/// as a `promptBlocked` error with block reason `.other`). Because all input is the user's own
/// private content, we set every supported harm category to the most permissive threshold the
/// installed SDK exposes (`.blockNone`, "all content will be allowed").
extension SafetySetting {
    /// One `SafetySetting` per `HarmCategory` supported by the SDK, each set to `.blockNone`.
    static let permissive: [SafetySetting] = [
        SafetySetting(harmCategory: .harassment, threshold: .blockNone),
        SafetySetting(harmCategory: .hateSpeech, threshold: .blockNone),
        SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockNone),
        SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
    ]
}
