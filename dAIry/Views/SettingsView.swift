import SwiftUI

struct SettingsView: View {

    // MARK: - Dependencies

    let apiKeyManager: APIKeyManaging
    let scheduler: Scheduling

    // MARK: - Local State

    @State private var collectionTime: Date
    @State private var apiKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var validationMessage: String?
    @State private var validationSuccess: Bool = false
    @State private var keyStatus: APIKeyStatus

    // MARK: - Private

    private var schedulerRef: Scheduling

    // MARK: - Init

    init(apiKeyManager: APIKeyManaging, scheduler: Scheduling) {
        self.apiKeyManager = apiKeyManager
        self.scheduler = scheduler
        self.schedulerRef = scheduler

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

    // MARK: - Body

    var body: some View {
        Form {
            // MARK: Task 8.1 — Daily Collection Time Picker
            Section {
                DatePicker(
                    "Collection Time",
                    selection: $collectionTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: collectionTime) { _, newValue in
                    let calendar = Calendar.current
                    let components = DateComponents(
                        hour: calendar.component(.hour, from: newValue),
                        minute: calendar.component(.minute, from: newValue)
                    )
                    var mutableScheduler = schedulerRef
                    mutableScheduler.configuredTime = components
                    mutableScheduler.scheduleDailyCollection(at: components)
                }
            } header: {
                Text("Daily Collection")
            } footer: {
                Text("The app will collect your data and generate a diary entry at this time each day.")
            }

            // MARK: Tasks 8.2–8.5 — Gemini API Key Management
            Section {
                // Task 8.5 — Key status display
                HStack {
                    Text("Status")
                    Spacer()
                    Text(keyStatusLabel)
                        .foregroundColor(keyStatusColor)
                }

                if keyStatus == .valid {
                    // Key is saved — only show remove option
                    Text("Your Gemini API key is configured and ready to use.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Remove API Key", role: .destructive) {
                        removeKey()
                    }
                } else {
                    // No valid key — show input and save button
                    SecureField("Enter Gemini API Key", text: $apiKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button {
                        Task { await saveKey() }
                    } label: {
                        HStack {
                            Text("Save Key")
                            if isValidating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(apiKeyInput.isEmpty || isValidating)

                    // Validation result message
                    if let message = validationMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(validationSuccess ? .green : .red)
                    }
                }
            } header: {
                Text("Gemini API Key")
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Key Status Helpers

    private var keyStatusLabel: String {
        switch keyStatus {
        case .notConfigured:
            return "Not Configured"
        case .valid:
            return "Valid"
        case .invalid:
            return "Invalid"
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
