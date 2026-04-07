import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasCompletedOnboarding: Bool =
        UserDefaults.standard.bool(forKey: OnboardingView.hasCompletedOnboardingKey)

    var body: some View {
        let apiKeyManager = APIKeyManager()
        let permissionManager = PermissionManager()
        let storageManager = StorageManager(modelContext: modelContext)
        let dataCollector = DataCollector(permissionManager: permissionManager)
        let diaryGenerator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let scheduler = DailyScheduler(
            dataCollector: dataCollector,
            diaryGenerator: diaryGenerator,
            storage: storageManager
        )

        if hasCompletedOnboarding {
            DiaryListView(
                storageManager: storageManager,
                dataCollector: dataCollector,
                diaryGenerator: diaryGenerator,
                apiKeyManager: apiKeyManager,
                scheduler: scheduler
            )
        } else {
            OnboardingView(
                permissionManager: permissionManager,
                onComplete: {
                    hasCompletedOnboarding = true
                }
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
