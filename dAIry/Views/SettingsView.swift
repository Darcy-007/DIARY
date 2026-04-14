import SwiftUI

struct SettingsView: View {

    // MARK: - Dependencies

    let apiKeyManager: APIKeyManaging
    let scheduler: Scheduling
    @ObservedObject var languageManager: LanguageManager

    // MARK: - Local State

    @State private var collectionTime: Date
    @State private var apiKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var validationMessage: String?
    @State private var validationSuccess: Bool = false
    @State private var keyStatus: APIKeyStatus

    // MARK: - Init

    init(apiKeyManager: APIKeyManaging, scheduler: Scheduling, languageManager: LanguageManager) {
        self.apiKeyManager = apiKeyManager
        self.scheduler = scheduler
        self.languageManager = languageManager

        // Derive initial key status
        let initialStatus: APIKeyStatus = apiKeyManager.isKeyConfigured() ? .valid : .notConfigured
        _keyStatus = State(initialValue: initialStatus)

        // Convert scheduler's configuredTime (DateComponents) to a Date for the picker
        let components = scheduler.configuredTime
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = components.hour ?? 21
        dateComponents.minute = components.minute ?? 0
        let date = calendar.date(from: dateComponents) ?? Date()
        _collectionTime = State(initialValue: date)
    }

    // MARK: - Localized Strings

    private var s: L10n { L10n(lang: languageManager) }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                DatePicker(
                    s.collectionTime,
                    selection: $collectionTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: collectionTime) { _, newValue in
                    let calendar = Calendar.current
                    let components = DateComponents(
                        hour: calendar.component(.hour, from: newValue),
                        minute: calendar.component(.minute, from: newValue)
                    )
                    scheduler.scheduleDailyCollection(at: components)
                }
            } header: {
                Text(s.dailyCollection)
            } footer: {
                Text(s.collectionTimeFooter)
            }

            Section {
                HStack {
                    Text(s.status)
                    Spacer()
                    Text(keyStatusLabel)
                        .foregroundColor(keyStatusColor)
                }

                if keyStatus == .valid {
                    Text(s.apiKeyConfigured)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(s.removeApiKey, role: .destructive) {
                        removeKey()
                    }
                } else {
                    SecureField(s.enterApiKey, text: $apiKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button {
                        Task { await saveKey() }
                    } label: {
                        HStack {
                            Text(s.saveKey)
                            if isValidating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(apiKeyInput.isEmpty || isValidating)

                    if let message = validationMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(validationSuccess ? .green : .red)
                    }
                }
            } header: {
                Text(s.geminiApiKey)
            }

            // Language picker
            Section {
                Picker(s.language, selection: $languageManager.current) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            } header: {
                Text(s.language)
            }
        }
        .navigationTitle(s.settings)
        .onAppear {
            // Refresh time from scheduler in case it was updated
            let components = scheduler.configuredTime
            let calendar = Calendar.current
            var dc = DateComponents()
            dc.hour = components.hour ?? 21
            dc.minute = components.minute ?? 0
            if let date = calendar.date(from: dc) {
                collectionTime = date
            }
            keyStatus = apiKeyManager.isKeyConfigured() ? .valid : .notConfigured
        }
    }

    // MARK: - Key Status Helpers

    private var keyStatusLabel: String {
        switch keyStatus {
        case .notConfigured: return s.notConfigured
        case .valid: return s.valid
        case .invalid: return s.invalid
        }
    }

    private var keyStatusColor: Color {
        switch keyStatus {
        case .notConfigured:
            return .red
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }

    // MARK: - Actions

    private func saveKey() async {
        isValidating = true
        validationMessage = nil

        do {
            let result = try await apiKeyManager.saveKey(apiKeyInput)
            switch result {
            case .valid:
                validationMessage = "API key saved successfully."
                validationSuccess = true
                keyStatus = .valid
                apiKeyInput = ""
            case .invalid(let reason):
                validationMessage = reason
                validationSuccess = false
                keyStatus = .invalid
            case .networkError(let error):
                validationMessage = "Network error: \(error.localizedDescription)"
                validationSuccess = false
            }
        } catch {
            validationMessage = "Error: \(error.localizedDescription)"
            validationSuccess = false
        }

        isValidating = false
    }

    private func removeKey() {
        do {
            try apiKeyManager.deleteKey()
            keyStatus = .notConfigured
            validationMessage = nil
            apiKeyInput = ""
        } catch {
            validationMessage = "Failed to remove key: \(error.localizedDescription)"
            validationSuccess = false
        }
    }
}
