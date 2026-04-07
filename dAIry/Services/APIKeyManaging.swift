import Foundation

protocol APIKeyManaging {
    func saveKey(_ key: String) async throws -> APIKeyValidationResult
    func getKey() -> String?
    func deleteKey() throws
    func isKeyConfigured() -> Bool
    func validateKey(_ key: String) async -> APIKeyValidationResult
}
