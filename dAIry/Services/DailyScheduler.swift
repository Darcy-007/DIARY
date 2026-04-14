import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

final class DailyScheduler: Scheduling {

    // MARK: - Constants

    static let taskIdentifier = "com.dairy.dailyCollection"

    private enum UserDefaultsKeys {
        static let configuredHour = "DailyScheduler.configuredHour"
        static let configuredMinute = "DailyScheduler.configuredMinute"
    }

    // MARK: - Dependencies

    private let dataCollector: DataCollecting
    private let diaryGenerator: DiaryGenerating
    private let storage: StorageManaging
    private let userDefaults: UserDefaults

    // MARK: - Scheduling Protocol

    var configuredTime: DateComponents {
        get {
            let hour = userDefaults.object(forKey: UserDefaultsKeys.configuredHour) as? Int ?? 21
            let minute = userDefaults.object(forKey: UserDefaultsKeys.configuredMinute) as? Int ?? 0
            return DateComponents(hour: hour, minute: minute)
        }
        set {
            userDefaults.set(newValue.hour ?? 21, forKey: UserDefaultsKeys.configuredHour)
            userDefaults.set(newValue.minute ?? 0, forKey: UserDefaultsKeys.configuredMinute)
        }
    }

    // MARK: - Init

    init(dataCollector: DataCollecting,
         diaryGenerator: DiaryGenerating,
         storage: StorageManaging,
         userDefaults: UserDefaults = .standard) {
        self.dataCollector = dataCollector
        self.diaryGenerator = diaryGenerator
        self.storage = storage
        self.userDefaults = userDefaults
    }

    // MARK: - Task Registration (6.2)

    /// Call this at app launch to register the background task handler.
    #if os(iOS)
    static func registerBackgroundTask(handler: @escaping (BGProcessingTask) -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handler(processingTask)
        }
    }
    #endif

    // MARK: - Schedule Daily Collection (6.3)

    func scheduleDailyCollection(at time: DateComponents) {
        configuredTime = time
        print("[dAIry] scheduleDailyCollection called with hour: \(time.hour ?? -1), minute: \(time.minute ?? -1)")
        #if os(iOS)
        scheduleNextTask(at: time)
        #endif
    }

    func cancelScheduledCollection() {
        #if os(iOS)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        #endif
    }

    // MARK: - Task Execution (6.4)

    /// Called by the background task handler to perform collection and generation.
    #if os(iOS)
    func handleBackgroundTask(_ task: BGProcessingTask) {
        print("[dAIry] handleBackgroundTask started")
        let workItem = Task {
            do {
                let window = CollectionWindow.today()
                print("[dAIry] Collection window: \(window.start) to \(window.end)")

                if storage.entryExists(for: window.date) {
                    print("[dAIry] Diary already exists for today, skipping auto-generation")
                    task.setTaskCompleted(success: true)
                    scheduleNextTask(at: configuredTime)
                    return
                }

                print("[dAIry] Collecting data...")
                let collectedData = try await dataCollector.collectAll(for: window)
                print("[dAIry] Generating diary...")
                let entry = try await diaryGenerator.generate(from: collectedData)
                try storage.save(entry)
                print("[dAIry] Diary auto-generated and saved successfully")

                task.setTaskCompleted(success: true)
                // Schedule next occurrence
                scheduleNextTask(at: configuredTime)
            } catch {
                task.setTaskCompleted(success: false)
                // 6.5: Retry on failure — schedule for next available opportunity
                scheduleRetry()
            }
        }

        // Handle system-initiated expiration
        task.expirationHandler = {
            workItem.cancel()
            // Re-schedule for next available opportunity on expiration
            self.scheduleRetry()
        }
    }
    #endif

    // MARK: - Private Helpers

    #if os(iOS)
    private func scheduleNextTask(at time: DateComponents) {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true

        if let nextDate = nextOccurrence(of: time) {
            request.earliestBeginDate = nextDate
            print("[dAIry] Scheduling background task for: \(nextDate)")
        } else {
            print("[dAIry] WARNING: Could not calculate next occurrence for time \(time)")
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[dAIry] Background task submitted successfully")
        } catch {
            print("[dAIry] ERROR: Failed to schedule background task: \(error)")
        }
    }

    private func scheduleRetry() {
        let retryDate = Date(timeIntervalSinceNow: 15 * 60)
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = retryDate

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[dAIry] Retry scheduled for: \(retryDate)")
        } catch {
            print("[dAIry] ERROR: Failed to schedule retry: \(error)")
        }
    }
    #endif

    func nextOccurrence(of time: DateComponents, calendar: Calendar = .current) -> Date? {
        let now = Date()
        // Try today first
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = time.hour
        todayComponents.minute = time.minute
        todayComponents.second = 0

        if let todayDate = calendar.date(from: todayComponents), todayDate > now {
            // Today's scheduled time hasn't passed yet
            return todayDate
        }

        // Otherwise schedule for tomorrow
        return calendar.nextDate(
            after: now,
            matching: time,
            matchingPolicy: .nextTime
        )
    }
}
