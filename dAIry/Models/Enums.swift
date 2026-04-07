import Foundation

enum DataSource: String, CaseIterable, Codable {
    case photos
    case healthKit
    case transactions
}

enum AuthorizationStatus: String, Codable {
    case notDetermined
    case authorized
    case denied
    case revoked
}

enum APIKeyValidationResult: Equatable {
    case valid
    case invalid(reason: String)
    case networkError(Error)

    static func == (lhs: APIKeyValidationResult, rhs: APIKeyValidationResult) -> Bool {
        switch (lhs, rhs) {
        case (.valid, .valid): return true
        case (.invalid(let l), .invalid(let r)): return l == r
        case (.networkError, .networkError): return true
        default: return false
        }
    }
}

enum APIKeyStatus: String, Codable {
    case notConfigured
    case valid
    case invalid
}
