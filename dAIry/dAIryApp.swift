import SwiftUI
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

#if !TESTING
@main
#endif
struct dAIryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DiaryEntry.self
        ])

        let storeURL = URL.applicationSupportDirectory
            .appending(path: "dAIry.store")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: storeURL.path(percentEncoded: false)) {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: storeURL.path(percentEncoded: false)
                )
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        #if os(iOS)
        let container = sharedModelContainer
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: DailyScheduler.taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            print("[dAIry] Background task fired!")

            let context = ModelContext(container)
            let apiKeyManager = APIKeyManager()
            let permissionManager = PermissionManager()
            let storageManager = StorageManager(modelContext: context)
            let dataCollector = DataCollector(permissionManager: permissionManager)
            let diaryGenerator = DiaryGenerator(apiKeyManager: apiKeyManager)
            let scheduler = DailyScheduler(
                dataCollector: dataCollector,
                diaryGenerator: diaryGenerator,
                storage: storageManager
            )
            scheduler.handleBackgroundTask(processingTask)
        }
        print("[dAIry] Background task registered for identifier: \(DailyScheduler.taskIdentifier)")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
