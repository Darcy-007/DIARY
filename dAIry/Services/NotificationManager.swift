import Foundation
import UserNotifications

/// Manages local notification reminders for the daily diary.
///
/// Unlike `BGProcessingTask` (which the system schedules opportunistically),
/// a `UNCalendarNotificationTrigger` fires at the exact configured time even
/// when the app is closed. Tapping the reminder sets `shouldGenerateOnLaunch`
/// so the UI can auto-generate today's entry on the next foreground pass.
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    // MARK: - Constants

    /// Fixed identifier so a re-schedule replaces (rather than stacks) the reminder.
    static let reminderIdentifier = "com.dairy.dailyReminder"

    /// userInfo key/value used by the tap handler to recognize this reminder.
    static let actionKey = "action"
    static let generateAction = "generateDiary"

    // MARK: - Shared Instance

    /// Shared instance so the app delegate and the SwiftUI hierarchy observe
    /// the same delegate/flag. The delegate must be installed early enough to
    /// receive the tap that launches the app from a terminated state.
    static let shared = NotificationManager()

    // MARK: - Published State

    /// Set to `true` when the user taps the reminder. Observed by the UI layer,
    /// which owns the collection/generation dependencies.
    @Published var shouldGenerateOnLaunch: Bool = false

    // MARK: - Dependencies

    private let center: UNUserNotificationCenter

    // MARK: - Init

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

    /// Requests alert/sound/badge authorization. Safe to call repeatedly; the
    /// system only prompts the user once.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("[dAIry] Notification authorization granted: \(granted)")
        } catch {
            print("[dAIry] ERROR: Notification authorization failed: \(error)")
        }
    }

    // MARK: - Scheduling

    /// Removes any existing pending reminder and schedules a new repeating one
    /// at the given hour/minute.
    func scheduleDailyReminder(at time: DateComponents, title: String, body: String) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [Self.actionKey: Self.generateAction]

        var triggerComponents = DateComponents()
        triggerComponents.hour = time.hour
        triggerComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("[dAIry] ERROR: Failed to schedule daily reminder: \(error)")
            } else {
                print("[dAIry] Daily reminder scheduled for hour: \(time.hour ?? -1), minute: \(time.minute ?? -1)")
            }
        }
    }

    /// Removes the pending and any already-delivered reminder.
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.reminderIdentifier])
        print("[dAIry] Daily reminder cancelled")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the reminder as a banner with sound even while the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle taps. When the user taps our daily reminder, flag the UI to
    /// auto-generate today's entry.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let action = userInfo[Self.actionKey] as? String, action == Self.generateAction {
            print("[dAIry] Daily reminder tapped — requesting diary generation")
            DispatchQueue.main.async {
                self.shouldGenerateOnLaunch = true
            }
        }
        completionHandler()
    }
}
