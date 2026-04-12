import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasCompletedOnboarding: Bool =
        UserDefaults.standard.bool(forKey: OnboardingView.hasCompletedOnboardingKey)
    @StateObject private var locationTracker = LocationTracker()

    var body: some View {
        let apiKeyManager = APIKeyManager()
        let permissionManager = PermissionManager()
        let storageManager = StorageManager(modelContext: modelContext)
        let dataCollector = DataCollector(permissionManager: permissionManager, locationTracker: locationTracker)
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
            .onAppear {
                // Start location tracking if authorized
                if locationTracker.authorizationStatus == .authorizedAlways ||
                   locationTracker.authorizationStatus == .authorizedWhenInUse {
                    locationTracker.startTracking()
                }
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
