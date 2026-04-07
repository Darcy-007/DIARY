import Foundation

struct HealthData {
    let stepCount: Int
    let walkingRunningDistance: Double   // in meters
    let activeEnergyBurned: Double      // in kilocalories
}

struct HealthSummary: Codable {
    let stepCount: Int
    let walkingRunningDistanceMeters: Double
    let activeEnergyBurnedKcal: Double
}
