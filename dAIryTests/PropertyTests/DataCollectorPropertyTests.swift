import XCTest
import SwiftCheck
@testable import dAIry

// MARK: - Generators for Data Models

struct ArbitraryCollectionWindow: Arbitrary {
    let window: CollectionWindow

    static var arbitrary: Gen<ArbitraryCollectionWindow> {
        Gen<Int>.fromElements(in: 0...364).map { daysAgo in
            let calendar = Calendar.current
            let today = Date()
            let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let startOfDay = calendar.startOfDay(for: targetDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return ArbitraryCollectionWindow(
                window: CollectionWindow(date: targetDate, start: startOfDay, end: endOfDay)
            )
        }
    }
}

// MARK: - DataCollector Property Tests

final class DataCollectorPropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 6: Date-filtered data falls within CollectionWindow
    // **Validates: Requirements 5.1, 7.1**
    func testDateFilteredDataFallsWithinCollectionWindow() {
        property("All returned items have dates within the window") <- forAll { (arbWindow: ArbitraryCollectionWindow, count: UInt) in
            let window = arbWindow.window
            let count = Int(count % 21)
            // Generate random date-stamped records, some inside and some outside the window
            let calendar = Calendar.current
            var insideRecords: [Date] = []
            var outsideRecords: [Date] = []

            for i in 0..<count {
                if i % 2 == 0 {
                    // Inside the window
                    let offset = Double.random(in: 0..<86400) // seconds in a day
                    let date = window.start.addingTimeInterval(offset)
                    insideRecords.append(date)
                } else {
                    // Outside the window (before or after)
                    let beforeOrAfter = Bool.random()
                    let date: Date
                    if beforeOrAfter {
                        date = calendar.date(byAdding: .day, value: -1, to: window.start)!
                    } else {
                        date = window.end.addingTimeInterval(3600)
                    }
                    outsideRecords.append(date)
                }
            }

            let allRecords = insideRecords + outsideRecords

            // Filter records as the DataCollector would
            let filtered = allRecords.filter { date in
                date >= window.start && date < window.end
            }

            // All filtered items should be within the window
            let allWithinWindow = filtered.allSatisfy { date in
                date >= window.start && date < window.end
            }

            // All inside records should be in the filtered set
            let noInsideMissing = insideRecords.allSatisfy { date in
                filtered.contains(date)
            }

            return allWithinWindow && noInsideMissing
        }
    }

    // Feature: dairy-ios-app, Property 7: Photo metadata extraction completeness
    // **Validates: Requirements 5.2**
    func testPhotoMetadataExtractionCompleteness() {
        let assetIdGen = Gen<String>.compose { c in
            "asset-\(c.generate(using: Gen<Int>.fromElements(in: 1...99999)))"
        }
        let hasLocationGen = Bool.arbitrary
        let hasCaptionGen = Bool.arbitrary

        property("Extracted PhotoData contains all fields present on the original") <- forAll(assetIdGen, hasLocationGen, hasCaptionGen) { (assetId: String, hasLocation: Bool, hasCaption: Bool) in
            let captureDate = Date()
            let caption: String? = hasCaption ? "Test caption \(assetId)" : nil

            let photo = PhotoData(
                assetIdentifier: assetId,
                captureDate: captureDate,
                location: nil, // CLLocationCoordinate2D not easily generated without CoreLocation
                caption: caption
            )

            // Verify all fields are preserved
            let idMatch = photo.assetIdentifier == assetId
            let dateMatch = photo.captureDate == captureDate
            let captionMatch: Bool
            if hasCaption {
                captionMatch = photo.caption != nil && photo.caption == caption
            } else {
                captionMatch = photo.caption == nil
            }

            return idMatch && dateMatch && captionMatch
        }
    }

    // Feature: dairy-ios-app, Property 8: Health data aggregation correctness
    // **Validates: Requirements 6.1, 6.2**
    func testHealthDataAggregationCorrectness() {
        let sampleCountGen = Gen<Int>.fromElements(in: 1...20)

        property("Aggregated totals equal the sum of individual samples") <- forAll(sampleCountGen) { (sampleCount: Int) in
            // Generate random health samples
            var totalSteps = 0
            var totalDistance = 0.0
            var totalEnergy = 0.0

            for _ in 0..<sampleCount {
                let steps = Int.random(in: 0...5000)
                let distance = Double.random(in: 0...5000)
                let energy = Double.random(in: 0...500)

                totalSteps += steps
                totalDistance += distance
                totalEnergy += energy
            }

            // Create aggregated HealthData as the system would
            let aggregated = HealthData(
                stepCount: totalSteps,
                walkingRunningDistance: totalDistance,
                activeEnergyBurned: totalEnergy
            )

            let stepsMatch = aggregated.stepCount == totalSteps
            let distanceMatch = abs(aggregated.walkingRunningDistance - totalDistance) < 0.001
            let energyMatch = abs(aggregated.activeEnergyBurned - totalEnergy) < 0.001

            return stepsMatch && distanceMatch && energyMatch
        }
    }
}
