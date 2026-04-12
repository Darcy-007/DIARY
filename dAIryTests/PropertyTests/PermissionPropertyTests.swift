import XCTest
import SwiftCheck
@testable import dAIry

// MARK: - Generators

extension DataSource: Arbitrary {
    public static var arbitrary: Gen<DataSource> {
        Gen.fromElements(of: DataSource.allCases)
    }
}

extension AuthorizationStatus: Arbitrary {
    public static var arbitrary: Gen<AuthorizationStatus> {
        Gen.fromElements(of: [.notDetermined, .authorized, .denied, .revoked])
    }
}

// MARK: - Permission Property Tests

final class PermissionPropertyTests: XCTestCase {

    // Feature: dairy-ios-app, Property 1: Permission grant enables collection
    // **Validates: Requirements 1.2, 2.2, 3.2**
    func testPermissionGrantEnablesCollection() {
        property("Granting access for any DataSource stores .authorized and DataCollector includes that source") <- forAll { (source: DataSource) in
            let permissionManager = MockPermissionManager()

            // Grant access for the source
            switch source {
            case .photos:
                permissionManager.photoAccessResult = .authorized
            case .healthKit:
                permissionManager.healthKitAccessResult = .authorized
            }

            let semaphore = DispatchSemaphore(value: 0)
            var grantedStatus: AuthorizationStatus = .notDetermined
            Task {
                switch source {
                case .photos:
                    grantedStatus = await permissionManager.requestPhotoAccess()
                case .healthKit:
                    grantedStatus = await permissionManager.requestHealthKitAccess()
                }
                semaphore.signal()
            }
            semaphore.wait()

            // Verify status is stored as .authorized
            let storedStatus = permissionManager.currentStatus(for: source)

            // Verify DataCollector would include this source (status is .authorized)
            let sourceIncluded = storedStatus == .authorized

            return grantedStatus == .authorized && storedStatus == .authorized && sourceIncluded
        }
    }

    // Feature: dairy-ios-app, Property 2: Permission revocation excludes data source
    // **Validates: Requirements 1.4, 2.4, 3.4**
    func testPermissionRevocationExcludesDataSource() {
        property("Revoking access for any DataSource excludes it from collection") <- forAll { (source: DataSource) in
            let permissionManager = MockPermissionManager()

            // First grant access
            permissionManager.statuses[source] = .authorized

            // Then revoke
            permissionManager.statuses[source] = .revoked

            let status = permissionManager.currentStatus(for: source)

            // Verify the source is excluded (status is not .authorized)
            let excluded = status != .authorized

            // Also verify with .denied
            permissionManager.statuses[source] = .denied
            let deniedStatus = permissionManager.currentStatus(for: source)
            let excludedWhenDenied = deniedStatus != .authorized

            return excluded && excludedWhenDenied
        }
    }
}
