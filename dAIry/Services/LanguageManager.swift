import Foundation

enum AppLanguage: String, CaseIterable, Codable {
    case english = "en"
    case chinese = "zh"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    var geminiInstruction: String {
        switch self {
        case .english: return "Write the diary entry in English."
        case .chinese: return "请用中文写这篇日记。"
        }
    }
}

final class LanguageManager: ObservableObject {
    private static let key = "appLanguage"

    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.key)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let lang = AppLanguage(rawValue: raw) {
            self.current = lang
        } else {
            self.current = .english
        }
    }

    func localizedString(_ en: String, zh: String) -> String {
        current == .chinese ? zh : en
    }
}
