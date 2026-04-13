import Foundation

struct L10n {
    let lang: LanguageManager

    // MARK: - General
    var appName: String { "dAIry" }

    // MARK: - Onboarding
    var welcomeTitle: String { lang.localizedString("Welcome to dAIry", zh: "欢迎使用 dAIry") }
    var welcomeDescription: String { lang.localizedString(
        "Your AI-powered daily diary. dAIry collects photos, health data, and location to write a personal narrative of your day.",
        zh: "你的AI日记助手。dAIry收集照片、健康数据和位置信息，为你撰写每日日记。"
    )}
    var getStarted: String { lang.localizedString("Get Started", zh: "开始使用") }
    var continueText: String { lang.localizedString("Continue", zh: "继续") }
    var skipForNow: String { lang.localizedString("Skip for Now", zh: "暂时跳过") }
    var configureInSettings: String { lang.localizedString("Configure in Settings", zh: "前往设置") }

    // Permissions
    var photoLibraryTitle: String { lang.localizedString("Photo Library", zh: "照片库") }
    var photoLibraryDesc: String { lang.localizedString(
        "dAIry uses your photos to include visual memories in your diary entries.",
        zh: "dAIry使用你的照片，将视觉记忆融入日记。"
    )}
    var allowPhotoAccess: String { lang.localizedString("Allow Photo Access", zh: "允许访问照片") }

    var healthTitle: String { lang.localizedString("Health Data", zh: "健康数据") }
    var healthDesc: String { lang.localizedString(
        "dAIry reads your step count, distance, and active energy to capture your daily activity.",
        zh: "dAIry读取你的步数、距离和活动能量，记录每日运动。"
    )}
    var allowHealthAccess: String { lang.localizedString("Allow Health Access", zh: "允许访问健康") }

    var locationTitle: String { lang.localizedString("Location", zh: "位置信息") }
    var locationDesc: String { lang.localizedString(
        "dAIry tracks the places you visit throughout the day to add context to your diary entries.",
        zh: "dAIry追踪你一天中去过的地方，为日记增添背景信息。"
    )}
    var allowLocationAccess: String { lang.localizedString("Allow Location Access", zh: "允许访问位置") }

    var apiKeyTitle: String { lang.localizedString("Gemini API Key", zh: "Gemini API 密钥") }
    var apiKeyDesc: String { lang.localizedString(
        "dAIry uses Google Gemini to generate your diary entries. You'll need to provide your own API key.",
        zh: "dAIry使用Google Gemini生成日记。你需要提供自己的API密钥。"
    )}

    var accessGranted: String { lang.localizedString("Access Granted", zh: "已授权") }
    var accessDenied: String { lang.localizedString("Access Denied", zh: "已拒绝") }

    // MARK: - Main UI
    var noDiaryEntries: String { lang.localizedString("No Diary Entries", zh: "暂无日记") }
    var noDiaryEntriesDesc: String { lang.localizedString(
        "Tap Generate Diary to create your first entry.",
        zh: "点击生成日记来创建你的第一篇日记。"
    )}
    var generateDiary: String { lang.localizedString("Generate Diary", zh: "生成日记") }
    var generating: String { lang.localizedString("Generating…", zh: "生成中…") }
    var apiKeyNotConfiguredBanner: String { lang.localizedString("API Key Not Configured", zh: "API密钥未配置") }
    var apiKeyNotConfiguredDesc: String { lang.localizedString(
        "Tap to open Settings and add your Gemini API key.",
        zh: "点击前往设置添加你的Gemini API密钥。"
    )}
    var configureApiKeyHint: String { lang.localizedString(
        "Configure an API key in Settings to generate entries.",
        zh: "请在设置中配置API密钥以生成日记。"
    )}

    // Conflict
    var entryAlreadyExists: String { lang.localizedString("Entry Already Exists", zh: "日记已存在") }
    var entryConflictMessage: String { lang.localizedString(
        "A diary entry already exists for today. Would you like to replace it or create a supplemental entry?",
        zh: "今天已有一篇日记。你想替换它还是创建补充日记？"
    )}
    var replace: String { lang.localizedString("Replace", zh: "替换") }
    var addSupplemental: String { lang.localizedString("Add Supplemental", zh: "添加补充") }
    var cancel: String { lang.localizedString("Cancel", zh: "取消") }

    // MARK: - Detail View
    var entry: String { lang.localizedString("Entry", zh: "日记") }
    var supplementalEntry: String { lang.localizedString("Supplemental Entry", zh: "补充日记") }
    var deleteEntry: String { lang.localizedString("Delete", zh: "删除") }
    var deleteEntryTitle: String { lang.localizedString("Delete Entry?", zh: "删除日记？") }
    var deleteEntryMessage: String { lang.localizedString(
        "This diary entry will be permanently deleted.",
        zh: "此日记将被永久删除。"
    )}
    var photos: String { lang.localizedString("Photos", zh: "照片") }
    var health: String { lang.localizedString("Health", zh: "健康") }
    var steps: String { lang.localizedString("Steps", zh: "步数") }
    var distance: String { lang.localizedString("Distance", zh: "距离") }
    var energy: String { lang.localizedString("Energy", zh: "能量") }

    // MARK: - Settings
    var settings: String { lang.localizedString("Settings", zh: "设置") }
    var dailyCollection: String { lang.localizedString("Daily Collection", zh: "每日收集") }
    var collectionTime: String { lang.localizedString("Collection Time", zh: "收集时间") }
    var collectionTimeFooter: String { lang.localizedString(
        "The app will collect your data and generate a diary entry at this time each day.",
        zh: "应用将在每天此时间收集数据并生成日记。"
    )}
    var geminiApiKey: String { lang.localizedString("Gemini API Key", zh: "Gemini API 密钥") }
    var status: String { lang.localizedString("Status", zh: "状态") }
    var notConfigured: String { lang.localizedString("Not Configured", zh: "未配置") }
    var valid: String { lang.localizedString("Valid", zh: "有效") }
    var invalid: String { lang.localizedString("Invalid", zh: "无效") }
    var enterApiKey: String { lang.localizedString("Enter Gemini API Key", zh: "输入Gemini API密钥") }
    var saveKey: String { lang.localizedString("Save Key", zh: "保存密钥") }
    var removeApiKey: String { lang.localizedString("Remove API Key", zh: "移除API密钥") }
    var apiKeyConfigured: String { lang.localizedString(
        "Your Gemini API key is configured and ready to use.",
        zh: "你的Gemini API密钥已配置，可以使用。"
    )}
    var language: String { lang.localizedString("Language", zh: "语言") }
    var apiKeySaved: String { lang.localizedString("API key saved successfully.", zh: "API密钥保存成功。") }

    // MARK: - Errors
    var generationError: String { lang.localizedString("Generation Error", zh: "生成错误") }
    var ok: String { lang.localizedString("OK", zh: "好") }
}
