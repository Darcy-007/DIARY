import Foundation
import Security

// 11.3: API key is stored exclusively in the iOS Keychain using Security framework
// (SecItemAdd, SecItemCopyMatching, SecItemDelete). Not stored in UserDefaults or SwiftData.
final class APIKeyManager: APIKeyManaging {

    // MARK: - Constants

    private let service = "com.dairy.gemini-api-key"
    private let account = "gemini-api-key"
    private let session: URLSession

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - APIKeyManaging

    func saveKey(_ key: String) async throws -> APIKeyValidationResult {
        let result = await validateKey(key)
        switch result {
        case .valid:
            try storeKeyInKeychain(key)
        case .invalid, .networkError:
            break
        }
        return result
    }

    func getKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }

    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func isKeyConfigured() -> Bool {
        getKey() != nil
    }

    func validateKey(_ key: String) async -> APIKeyValidationResult {
        // 11.2: Gemini API validation uses HTTPS exclusively
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(key)") else {
            return .invalid(reason: "Invalid API key format")
        }

        do {
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError(KeychainError.unexpectedResponse)
            }

            switch httpResponse.statusCode {
            case 200:
                return .valid
            case 400, 401, 403:
                return .invalid(reason: "The provided API key is not valid. Please check your key and try again.")
            default:
                return .invalid(reason: "Unexpected response from Gemini API (status \(httpResponse.statusCode)).")
            }
        } catch {
            return .networkError(error)
        }
    }

    // MARK: - Private Helpers

    private func storeKeyInKeychain(_ key: String) throws {
        // Remove any existing key first
        try? deleteKey()

        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
}

// MARK: - Errors

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save key to Keychain (OSStatus: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete key from Keychain (OSStatus: \(status))"
        case .encodingFailed:
            return "Failed to encode API key"
        case .unexpectedResponse:
            return "Unexpected response from API"
        }
    }
}
