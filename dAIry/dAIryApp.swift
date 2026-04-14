import SwiftUI
import SwiftData

#if !TESTING
@main
#endif
struct dAIryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DiaryEntry.self
        ])

        // 11.1: Configure SwiftData store with NSFileProtectionComplete
        // to encrypt all stored diary entries and collected data at rest.
        // Data is inaccessible when the device is locked.
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

            // Apply NSFileProtectionComplete to the SwiftData store file
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
        // Register background task handler at app launch
        #if os(iOS)
        DailyScheduler.registerBackgroundTask { task in
            // The actual execution is handled by DailyScheduler.handleBackgroundTask
            // but we need a registered handler. The real work happens via the scheduler
            // instance in ContentView.
            task.setTaskCompleted(success: true)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
