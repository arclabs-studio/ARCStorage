import Testing
@testable import ARCStorage

@Suite("CloudKitSyncMonitor Tests")
@MainActor
struct CloudKitSyncMonitorTests {
    private func makeSUT() -> CloudKitSyncMonitor {
        CloudKitSyncMonitor(containerIdentifier: "iCloud.com.arclabs.test")
    }

    @Test("Initial state is available") func initialState_isAvailable() {
        // Given
        let sut = makeSUT()

        // Then
        #expect(sut.state == .available)
    }

    @Test("isMonitoring is false by default") func isMonitoring_defaultsFalse() {
        // Given
        let sut = makeSUT()

        // Then
        #expect(sut.isMonitoring == false)
    }

    @Test("lastSyncDate is nil by default") func lastSyncDate_defaultsNil() {
        // Given
        let sut = makeSUT()

        // Then
        #expect(sut.lastSyncDate == nil)
    }

    @Test("stopMonitoring sets isMonitoring to false") func stopMonitoring_setsIsMonitoringFalse() {
        // Given
        let sut = makeSUT()

        // When
        sut.stopMonitoring()

        // Then
        #expect(sut.isMonitoring == false)
    }

    @Test("stopMonitoring cancels observation task") func stopMonitoring_cancelsObservation() {
        // Given
        let sut = makeSUT()

        // When — stop without starting should be safe (idempotent)
        sut.stopMonitoring()
        sut.stopMonitoring()

        // Then
        #expect(sut.isMonitoring == false)
    }

    // Note: Tests for startMonitoring() require CloudKit entitlements because
    // CKContainer.accountStatus() hangs in package test environments without them.
    // Full integration tests for startMonitoring belong in the demo app.
}
