import Foundation
import GoogleGenerativeAI

// MARK: - Errors

enum ChatServiceError: Error, LocalizedError, Equatable {
    case apiKeyNotConfigured
    case emptyResponse
    case networkError(Error)
    case toolLoopExceeded

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "No valid Gemini API key is configured. Please add your API key in Settings."
        case .emptyResponse:
            return "The Gemini API returned an empty response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .toolLoopExceeded:
            return "The assistant took too many steps to answer. Please try rephrasing your question."
        }
    }

    static func == (lhs: ChatServiceError, rhs: ChatServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.apiKeyNotConfigured, .apiKeyNotConfigured): return true
        case (.emptyResponse, .emptyResponse): return true
        case (.networkError, .networkError): return true
        case (.toolLoopExceeded, .toolLoopExceeded): return true
        default: return false
        }
    }
}

// MARK: - Chat Message

/// A single message displayed in the chat UI.
struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
}

// MARK: - ChatService

/// Conversational service that answers questions about the user's diary entries.
///
/// Uses the GoogleGenerativeAI SDK's native function calling (tools): the model decides
/// when to call `listEntryDates`, `searchEntries`, or `getEntry`. Each call is executed
/// locally against `StorageManaging` and the result is sent back to the model. This avoids
/// stuffing every entry into the prompt — entries are retrieved on demand.
final class ChatService: ObservableObject {

    // MARK: - Dependencies

    private let apiKeyManager: APIKeyManaging
    private let storage: StorageManaging
    var language: AppLanguage = .english

    // MARK: - Constants

    /// Primary model first, fallback model second — see `GeminiModel`.
    private let modelNames = GeminiModel.names
    /// Cap on tool round-trips per user message to avoid infinite loops.
    private let maxToolRoundTrips = 5

    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Conversation State

    /// SDK chat session, lazily created on first message so tool/language config is current.
    private var chat: Chat?
    /// The model name the current `chat` session was built with, so we can detect whether a
    /// fallback retry is still possible (only retry once, and only if we haven't already
    /// fallen back).
    private var currentModelName: String?

    // MARK: - Init

    init(apiKeyManager: APIKeyManaging, storage: StorageManaging) {
        self.apiKeyManager = apiKeyManager
        self.storage = storage
    }

    // MARK: - Public API

    /// Sends a user message and returns the assistant's final text answer.
    ///
    /// Runs the function-calling loop: forwards the message + history with the diary tools,
    /// executes any function calls the model requests against `storage`, sends the responses
    /// back, and repeats until the model returns plain text (or the round-trip cap is hit).
    func send(_ message: String) async throws -> String {
        guard apiKeyManager.isKeyConfigured(), let apiKey = apiKeyManager.getKey() else {
            throw ChatServiceError.apiKeyNotConfigured
        }

        if chat == nil {
            currentModelName = modelNames[0]
            chat = makeChat(apiKey: apiKey, modelName: modelNames[0])
        }

        do {
            return try await sendWithToolLoop(message)
        } catch let error as ChatServiceError {
            throw error
        } catch {
            // Only fall back once, and only if we haven't already fallen back for this session.
            guard GeminiErrorClassifier.shouldFallback(error),
                  let modelUsed = currentModelName,
                  modelUsed == modelNames[0],
                  modelNames.count > 1 else {
                print("[dAIry] Chat error: \(error)")
                throw ChatServiceError.networkError(error)
            }

            let fallbackModelName = modelNames[1]
            if GeminiErrorClassifier.isPromptBlocked(error) {
                print("[dAIry] Chat prompt blocked on \(modelUsed), falling back to \(fallbackModelName)")
            } else {
                print("[dAIry] Chat rate limited on \(modelUsed), falling back to \(fallbackModelName)")
            }
            print("[dAIry] Warning: rebuilding chat session for fallback — conversation history will reset")

            currentModelName = fallbackModelName
            chat = makeChat(apiKey: apiKey, modelName: fallbackModelName)

            do {
                return try await sendWithToolLoop(message)
            } catch let error as ChatServiceError {
                throw error
            } catch {
                print("[dAIry] Chat error after fallback: \(error)")
                throw ChatServiceError.networkError(error)
            }
        }
    }

    /// Runs the tool-calling round-trip loop against the current `chat` session for one message.
    private func sendWithToolLoop(_ message: String) async throws -> String {
        guard let chat else {
            throw ChatServiceError.networkError(
                NSError(domain: "ChatService", code: -1)
            )
        }

        var response = try await chat.sendMessage(message)

        for roundTrip in 0..<maxToolRoundTrips {
            let functionCalls = response.functionCalls
            guard !functionCalls.isEmpty else {
                // Model returned a normal answer.
                guard let text = response.text, !text.isEmpty else {
                    throw ChatServiceError.emptyResponse
                }
                return text
            }

            print("[dAIry] Chat round-trip \(roundTrip + 1): model requested \(functionCalls.count) function call(s)")

            // Execute each requested function locally and collect responses.
            var responseParts: [ModelContent.Part] = []
            for call in functionCalls {
                print("[dAIry] Function call: \(call.name) args: \(call.args)")
                let result = execute(call)
                responseParts.append(.functionResponse(
                    FunctionResponse(name: call.name, response: result)
                ))
            }

            response = try await chat.sendMessage([
                ModelContent(role: "function", parts: responseParts)
            ])
        }

        // Exhausted round-trips: return any text the model produced, else error.
        if let text = response.text, !text.isEmpty {
            return text
        }
        throw ChatServiceError.toolLoopExceeded
    }

    /// Resets the conversation history.
    func reset() {
        chat = nil
        currentModelName = nil
    }

    // MARK: - Model / Tools Setup

    private func makeChat(apiKey: String, modelName: String) -> Chat {
        print("[dAIry] Chat using model \(modelName)")
        let model = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            safetySettings: SafetySetting.permissive,
            tools: [diaryTool],
            systemInstruction: systemInstruction
        )
        return model.startChat()
    }

    private var systemInstruction: ModelContent {
        let instruction = """
        You are the assistant inside dAIry, a personal diary app. Answer the user's questions \
        about their diary entries. You do not have the diary contents up front — you MUST use the \
        provided tools to retrieve information:
        - Call listEntryDates to discover which dates have entries.
        - Call searchEntries with a keyword to find entries mentioning a topic (e.g. "dogs", "walk").
        - Call getEntry with a specific yyyy-MM-dd date to read the full entry for that day.
        Prefer searchEntries for topic questions and getEntry to read details. Base your answers \
        only on retrieved entries; if nothing relevant is found, say so honestly. Cite the relevant \
        dates in your answer when helpful. \(language.geminiInstruction)
        """
        return ModelContent(role: "system", parts: [.text(instruction)])
    }

    private var diaryTool: Tool {
        Tool(functionDeclarations: [
            FunctionDeclaration(
                name: "listEntryDates",
                description: "Returns all dates (yyyy-MM-dd) that have a diary entry, newest first. "
                    + "Lightweight — does not include entry text.",
                parameters: nil
            ),
            FunctionDeclaration(
                name: "searchEntries",
                description: "Searches diary entries whose text contains the given keyword "
                    + "(case-insensitive). Returns matching dates with short text snippets.",
                parameters: [
                    "keyword": Schema(
                        type: .string,
                        description: "The keyword or phrase to search for in diary entry text."
                    )
                ],
                requiredParameters: ["keyword"]
            ),
            FunctionDeclaration(
                name: "getEntry",
                description: "Returns the full diary text (plus health and location summary if "
                    + "available) for a specific date.",
                parameters: [
                    "date": Schema(
                        type: .string,
                        description: "The date to fetch, formatted as yyyy-MM-dd."
                    )
                ],
                requiredParameters: ["date"]
            )
        ])
    }

    // MARK: - Function Execution

    private func execute(_ call: FunctionCall) -> JSONObject {
        switch call.name {
        case "listEntryDates":
            return listEntryDates()
        case "searchEntries":
            let keyword: String
            if case let .string(value) = call.args["keyword"] {
                keyword = value
            } else {
                keyword = ""
            }
            return searchEntries(keyword: keyword)
        case "getEntry":
            let dateString: String
            if case let .string(value) = call.args["date"] {
                dateString = value
            } else {
                dateString = ""
            }
            return getEntry(dateString: dateString)
        default:
            print("[dAIry] Unknown function requested: \(call.name)")
            return ["error": .string("Unknown function: \(call.name)")]
        }
    }

    private func listEntryDates() -> JSONObject {
        let entries = storage.fetchAll()
        let dates = entries.map { isoFormatter.string(from: $0.date) }
        return ["dates": .array(dates.map { .string($0) })]
    }

    private func searchEntries(keyword: String) -> JSONObject {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ["matches": .array([])]
        }
        let entries = storage.fetchAll()
        let matches = entries
            .filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
            .map { entry -> JSONValue in
                .object([
                    "date": .string(isoFormatter.string(from: entry.date)),
                    "snippet": .string(snippet(from: entry.text))
                ])
            }
        return ["matches": .array(matches)]
    }

    private func getEntry(dateString: String) -> JSONObject {
        guard let date = isoFormatter.date(from: dateString) else {
            return ["error": .string("Invalid date format. Use yyyy-MM-dd.")]
        }
        guard let entry = storage.fetch(for: date) else {
            return ["found": .bool(false)]
        }

        var result: JSONObject = [
            "found": .bool(true),
            "date": .string(isoFormatter.string(from: entry.date)),
            "text": .string(entry.text),
            "isSupplemental": .bool(entry.isSupplemental)
        ]

        if let health = entry.healthSummary {
            result["health"] = .object([
                "steps": .number(Double(health.stepCount)),
                "distanceMeters": .number(health.walkingRunningDistanceMeters),
                "activeEnergyKcal": .number(health.activeEnergyBurnedKcal)
            ])
        }

        if let location = entry.locationSummary {
            result["locationVisitCount"] = .number(Double(location.visits.count))
        }

        return result
    }

    // MARK: - Helpers

    private func snippet(from text: String, maxLength: Int = 160) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        if collapsed.count > maxLength {
            return String(collapsed.prefix(maxLength)) + "…"
        }
        return collapsed
    }
}
