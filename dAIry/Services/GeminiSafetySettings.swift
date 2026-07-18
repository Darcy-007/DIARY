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

// MARK: - Model Fallback

/// Primary and fallback Gemini model identifiers, shared by `DiaryGenerator` and `ChatService`.
///
/// Two real-world failure modes motivate the fallback:
/// 1. `promptBlocked` errors (blockReason `.other`) that persist even with
///    `SafetySetting.permissive` applied — likely a non-configurable filter category.
/// 2. HTTP 429 `RESOURCE_EXHAUSTED` responses from the free-tier quota (5 requests/minute) for
///    `gemini-2.5-flash`.
///
/// Retrying against a different model uses a separate quota bucket and may apply different
/// safety filtering, so it's a reasonable fallback for both failure modes.
enum GeminiModel {
    static let primary = "gemini-2.5-flash"
    static let fallback = "gemini-3-flash-preview"
    /// Ordered primary-first, fallback-second.
    static let names = [primary, fallback]
}

// MARK: - Error Classification

/// Classifies Gemini SDK errors so callers can decide whether to retry against a fallback model.
///
/// `GoogleGenerativeAI`'s `RPCError` type (which wraps HTTP-level failures like a 429
/// `RESOURCE_EXHAUSTED` quota error) is `internal` to the SDK module — it can't be imported or
/// pattern-matched from app code. HTTP errors instead surface here as
/// `GenerateContentError.internalError(underlying:)` with the internal `RPCError` boxed inside
/// as `Error`. Printing that underlying error via `String(describing:)` still includes its
/// `httpResponseCode` field (confirmed against the SDK source at
/// `generative-ai-swift/Sources/GoogleAI/Errors.swift`), matching the
/// `RPCError(httpResponseCode: 429, ...)` text already seen in this app's logs — so we match on
/// that substring rather than guessing at a public error type that doesn't exist.
enum GeminiErrorClassifier {
    /// True if the model refused to generate content because the prompt was blocked
    /// (`GenerateContentError.promptBlocked`), regardless of block reason.
    static func isPromptBlocked(_ error: Error) -> Bool {
        if case GenerateContentError.promptBlocked = error {
            return true
        }
        return false
    }

    /// True if the error looks like an HTTP 429 / RESOURCE_EXHAUSTED rate-limit response.
    static func isRateLimited(_ error: Error) -> Bool {
        if case GenerateContentError.internalError(let underlying) = error {
            let description = String(describing: underlying)
            return description.contains("429") || description.contains("RESOURCE_EXHAUSTED")
        }
        return false
    }

    /// True if either condition warrants retrying against a fallback model.
    static func shouldFallback(_ error: Error) -> Bool {
        isPromptBlocked(error) || isRateLimited(error)
    }
}
