import Foundation

struct CollectionWindow {
    let date: Date          // The calendar date
    let start: Date         // Midnight local time
    let end: Date           // Next midnight local time
}

struct CollectedData {
    let window: CollectionWindow
    let photos: [PhotoData]
    let health: HealthData?
    let transactions: [TransactionData]
    var isEmpty: Bool { photos.isEmpty && health == nil && transactions.isEmpty }
}

extension CollectionWindow {
    static func today(calendar: Calendar = .current) -> CollectionWindow {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return CollectionWindow(date: now, start: startOfDay, end: endOfDay)
    }
}
