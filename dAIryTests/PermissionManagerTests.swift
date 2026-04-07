import Testing
import Foundation
@testable import dAIry

// Task 12.1: Test PermissionManager — first-launch flow, grant/deny/revoke transitions, denial messages

@Suite("PermissionManager Tests")
struct PermissionManagerTests {

    // MARK: - First Launch Flow

    @Test("First launch: all sources start as notDetermined")
    func firstLaunchAllNotDetermined() {
        let mock = MockPermissionManager()
        // Simulate first launch — no stored statuses
        for source in DataSource.allCases {
            #expect(mock.currentStatus(for: source) == .notDetermined)
        }
    }

    // MARK: - Grant / Deny / Revoke Transitions

    @Test("Grant photo access stores authorized status")
    func grantPhotoAccess() async {
        let mock = MockPermissionManager()
        mock.photoAccessResult = .authorized
        let status = await mock.requestPhotoAccess()
        #expect(status == .authorized)
        #expect(mock.currentStatus(for: .photos) == .authorized)
    }

    @Test("Deny HealthKit access stores denied status")
    func denyHealthKitAccess() async {
        let mock = MockPermissionManager()
        mock.healthKitAccessResult = .denied
        let status = await mock.requestHealthKitAccess()
        #expect(status == .denied)
        #expect(mock.currentStatus(for: .healthKit) == .denied)
    }

    @Test("Deny transaction access stores denied status")
    func denyTransactionAccess() async {
        let mock = MockPermissionManager()
        mock.transactionAccessResult = .denied
        let status = await mock.requestTransactionAccess()
        #expect(status == .denied)
        #expect(mock.currentStatus(for: .transactions) == .denied)
    }

    @Test("Revoke transition: authorized -> revoked")
    func revokeTransition() async {
        let mock = MockPermissionManager()
        mock.photoAccessResult = .authorized
        _ = await mock.requestPhotoAccess()
        #expect(mock.currentStatus(for: .photos) == .authorized)

        // Simulate revocation
        mock.statuses[.photos] = .revoked
        #expect(mock.currentStatus(for: .photos) == .revoked)
    }

    // MARK: - Denial Messages

    @Test("Denial message for photos")
    func denialMessagePhotos() {
        let msg = PermissionManager.denialMessage(for: .photos)
        #expect(msg.contains("Photo library access was denied"))
    }

    @Test("Denial message for HealthKit")
    func denialMessageHealthKit() {
        let msg = PermissionManager.denialMessage(for: .healthKit)
        #expect(msg.contains("HealthKit access was denied"))
    }

    @Test("Denial message for transactions")
    func denialMessageTransactions() {
        let msg = PermissionManager.denialMessage(for: .transactions)
        #expect(msg.contains("Transaction data access was denied"))
    }

    @Test("Revocation message for photos")
    func revocationMessagePhotos() {
        let msg = PermissionManager.revocationMessage(for: .photos)
        #expect(msg.contains("Photo library access was revoked"))
    }

    @Test("Revocation message for HealthKit")
    func revocationMessageHealthKit() {
        let msg = PermissionManager.revocationMessage(for: .healthKit)
        #expect(msg.contains("HealthKit access was revoked"))
    }

    @Test("Revocation message for transactions")
    func revocationMessageTransactions() {
        let msg = PermissionManager.revocationMessage(for: .transactions)
        #expect(msg.contains("Transaction data access was revoked"))
    }
}
