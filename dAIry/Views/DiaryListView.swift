import SwiftUI
import SwiftData

struct DiaryListView: View {

    // MARK: - Dependencies

    let storageManager: StorageManaging
    let dataCollector: DataCollecting
    let diaryGenerator: DiaryGenerating
    let apiKeyManager: APIKeyManaging
    let scheduler: Scheduling
    @ObservedObject var languageManager: LanguageManager

    // MARK: - State

    @State private var entries: [DiaryEntry] = []
    @State private var isGenerating: Bool = false
    @State private var showConflictAlert: Bool = false
    @State private var generationError: String?
    @State private var showErrorAlert: Bool = false
    @State private var isKeyConfigured: Bool = false
    @State private var searchText: String = ""
    @State private var showDatePicker: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var navigateToEntryId: UUID? = nil

    private var filteredEntries: [DiaryEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    private var datesWithEntries: Set<DateComponents> {
        let calendar = Calendar.current
        return Set(entries.map { calendar.dateComponents([.year, .month, .day], from: $0.date) })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom search bar with calendar icon
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search diary entries", text: $searchText)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button { showDatePicker = true } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // API key missing banner
                if !isKeyConfigured {
                    apiKeyBanner
                }

                List {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView(
                            "No Diary Entries",
                            systemImage: "book.closed",
                            description: Text(searchText.isEmpty
                                ? "Tap Generate Diary to create your first entry."
                                : "No entries match your search.")
                        )
                    } else {
                        ForEach(filteredEntries, id: \.id) { entry in
                            NavigationLink(value: entry.id) {
                                DiaryEntryRow(entry: entry)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("dAIry")
            .navigationDestination(for: UUID.self) { entryId in
                if let entry = entries.first(where: { $0.id == entryId }) {
                    DiaryDetailView(
                        entry: entry,
                        storageManager: storageManager,
                        onDelete: { refreshEntries() }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView(
                            apiKeyManager: apiKeyManager,
                            scheduler: scheduler,
                            languageManager: languageManager
                        )
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                // Task 9.3 — Manual generation button
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    generateButton
                }
                #else
                ToolbarItem(placement: .automatic) {
                    generateButton
                }
                #endif
            }
            // Task 9.4 — Conflict resolution alert
            .alert("Entry Already Exists", isPresented: $showConflictAlert) {
                Button("Replace") {
                    Task { await generateEntry(supplemental: false) }
                }
                Button("Add Supplemental") {
                    Task { await generateEntry(supplemental: true) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A diary entry already exists for today. Would you like to replace it or create a supplemental entry?")
            }
            .alert("Generation Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(generationError ?? "An unknown error occurred.")
            }
            .onAppear {
                refreshEntries()
                isKeyConfigured = apiKeyManager.isKeyConfigured()
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding()

                        if storageManager.fetch(for: selectedDate) == nil {
                            Text("No diary entry for this date")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.bottom)
                        }
                    }
                    .navigationTitle("Select Date")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Go") {
                                showDatePicker = false
                                if let entry = storageManager.fetch(for: selectedDate) {
                                    navigateToEntryId = entry.id
                                }
                            }
                            .disabled(storageManager.fetch(for: selectedDate) == nil)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .navigationDestination(item: $navigateToEntryId) { entryId in
                if let entry = entries.first(where: { $0.id == entryId }) {
                    DiaryDetailView(
                        entry: entry,
                        storageManager: storageManager,
                        onDelete: { refreshEntries() }
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    // Task 9.6 — API key missing banner with navigation to settings
    private var apiKeyBanner: some View {
        NavigationLink {
            SettingsView(
                apiKeyManager: apiKeyManager,
                scheduler: scheduler,
                languageManager: languageManager
            )
        } label: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("API Key Not Configured")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Tap to open Settings and add your Gemini API key.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .background(Color.orange)
        }
    }

    // Task 9.3 + 9.7 — Generate button with loading indicator and disabled state
    @ViewBuilder
    private var generateButton: some View {
        if isGenerating {
            ProgressView("Generating…")
        } else {
            VStack(spacing: 4) {
                Button {
                    Task { await handleGenerateTapped() }
                } label: {
                    Label("Generate Diary", systemImage: "sparkles")
                }
                .disabled(!isKeyConfigured)

                // Task 9.7 — Explanation when key is missing
                if !isKeyConfigured {
                    Text("Configure an API key in Settings to generate entries.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func refreshEntries() {
        entries = storageManager.fetchAll()
    }

    private func handleGenerateTapped() async {
        // Task 9.4 — Check for existing entry conflict
        if storageManager.entryExists(for: Date()) {
            showConflictAlert = true
        } else {
            await generateEntry(supplemental: false)
        }
    }

    private func generateEntry(supplemental: Bool) async {
        isGenerating = true
        defer {
            isGenerating = false
            refreshEntries()
        }

        do {
            let window = CollectionWindow.today()
            let collectedData = try await dataCollector.collectAll(for: window)

            let entry = try await diaryGenerator.generate(from: collectedData)

            if supplemental {
                entry.isSupplemental = true
            } else {
                // Replace: delete existing entry for today if present
                if let existing = storageManager.fetch(for: Date()) {
                    try storageManager.delete(existing)
                }
            }

            try storageManager.save(entry)
        } catch {
            generationError = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Entry Row

private struct DiaryEntryRow: View {
    let entry: DiaryEntry

    private var dateFormatted: String {
        entry.date.formatted(date: .long, time: .omitted)
    }

    private var preview: String {
        let text = entry.text
        if text.count > 100 {
            return String(text.prefix(100)) + "…"
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dateFormatted)
                    .font(.headline)
                if entry.isSupplemental {
                    Text("Supplemental")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            Text(preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
