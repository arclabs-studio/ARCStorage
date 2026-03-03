import Testing
@testable import ARCStorage

@Suite("CloudKitSyncMonitor Tests")
@MainActor struct CloudKitSyncMonitorTests {
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
}
