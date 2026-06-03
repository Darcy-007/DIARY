import SwiftUI
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasCompletedOnboarding: Bool =
        UserDefaults.standard.bool(forKey: OnboardingView.hasCompletedOnboardingKey)
    @StateObject private var locationTracker = LocationTracker()
    @StateObject private var languageManager = LanguageManager()

    var body: some View {
        let apiKeyManager = APIKeyManager()
        let permissionManager = PermissionManager()
        let storageManager = StorageManager(modelContext: modelContext)
        let dataCollector = DataCollector(permissionManager: permissionManager, locationTracker: locationTracker)
        let diaryGenerator = DiaryGenerator(apiKeyManager: apiKeyManager)
        let _ = { diaryGenerator.language = languageManager.current }()
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
                scheduler: scheduler,
                languageManager: languageManager
            )
            .onAppear {
                if locationTracker.isAuthorized {
                    locationTracker.startTracking()
                }
                // Schedule the daily background task on every app launch
                scheduler.scheduleDailyCollection(at: scheduler.configuredTime)
                // Diagnostic: confirm at runtime whether the request is actually queued
                #if os(iOS)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    BGTaskScheduler.shared.getPendingTaskRequests { requests in
                        print("[dAIry] Pending task requests: \(requests.count)")
                        for r in requests {
                            print("[dAIry]  - \(r.identifier) earliestBeginDate: \(String(describing: r.earliestBeginDate))")
                        }
                    }
                }
                #endif
            }
        } else {
            OnboardingView(
                permissionManager: permissionManager,
                locationTracker: locationTracker,
                onComplete: {
                    hasCompletedOnboarding = true
                    locationTracker.startTracking()
                }
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
