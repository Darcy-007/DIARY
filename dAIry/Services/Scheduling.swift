import Foundation

protocol Scheduling {
    func scheduleDailyCollection(at time: DateComponents)
    func cancelScheduledCollection()
    var configuredTime: DateComponents { get set } // Default: 21:00
}
