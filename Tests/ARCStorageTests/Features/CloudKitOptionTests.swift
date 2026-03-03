import Testing
@testable import ARCStorage

@Suite("CloudKitOption Tests") struct CloudKitOptionTests {
    // MARK: - CloudKitOption Equality

    @Test("Disabled equals disabled") func disabled_equalsDisabled() {
        // Given
        let lhs = CloudKitOption.disabled
        let rhs = CloudKitOption.disabled

        // Then
        #expect(lhs == rhs)
    }

    @Test("Enabled with same identifier are equal") func enabled_sameIdentifier_areEqual() {
        // Given
        let lhs = CloudKitOption.enabled(containerIdentifier: "iCloud.com.test")
        let rhs = CloudKitOption.enabled(containerIdentifier: "iCloud.com.test")

        // Then
        #expect(lhs == rhs)
    }

    @Test("Enabled and disabled are not equal") func enabled_andDisabled_areNotEqual() {
        // Given
        let lhs = CloudKitOption.enabled(containerIdentifier: "iCloud.com.test")
        let rhs = CloudKitOption.disabled

        // Then
        #expect(lhs != rhs)
    }

    @Test("Enabled with different identifiers are not equal") func enabled_differentIdentifiers_areNotEqual() {
        // Given
        let lhs = CloudKitOption.enabled(containerIdentifier: "iCloud.com.app1")
        let rhs = CloudKitOption.enabled(containerIdentifier: "iCloud.com.app2")

        // Then
        #expect(lhs != rhs)
    }
}

@Suite("SyncState Tests") struct SyncStateTests {
    // MARK: - SyncState Equality

    @Test("Available equals available") func available_equalsAvailable() {
        #expect(SyncState.available == SyncState.available)
    }

    @Test("Syncing equals syncing") func syncing_equalsSyncing() {
        #expect(SyncState.syncing == SyncState.syncing)
    }

    @Test("Unavailable with same reason are equal") func unavailable_sameReason_areEqual() {
        // Given
        let lhs = SyncState.unavailable(reason: .noAccount)
        let rhs = SyncState.unavailable(reason: .noAccount)

        // Then
        #expect(lhs == rhs)
    }

    @Test("Different states are not equal") func differentStates_areNotEqual() {
        #expect(SyncState.available != SyncState.syncing)
        #expect(SyncState.available != SyncState.unavailable(reason: .noAccount))
        #expect(SyncState.syncing != SyncState.unavailable(reason: .restricted))
    }

    // MARK: - UnavailableReason Equality

    @Test("UnavailableReason noAccount equals noAccount") func noAccount_equalsNoAccount() {
        #expect(UnavailableReason.noAccount == UnavailableReason.noAccount)
    }

    @Test("UnavailableReason restricted equals restricted") func restricted_equalsRestricted() {
        #expect(UnavailableReason.restricted == UnavailableReason.restricted)
    }

    @Test("UnavailableReason couldNotDetermine equals couldNotDetermine")
    func couldNotDetermine_equalsCouldNotDetermine() {
        #expect(UnavailableReason.couldNotDetermine == UnavailableReason.couldNotDetermine)
    }

    @Test("UnavailableReason temporarilyUnavailable equals temporarilyUnavailable")
    func temporarilyUnavailable_equalsTemporarilyUnavailable() {
        #expect(UnavailableReason.temporarilyUnavailable == UnavailableReason.temporarilyUnavailable)
    }

    @Test("UnavailableReason error with same message are equal") func error_sameMessage_areEqual() {
        #expect(UnavailableReason.error("fail") == UnavailableReason.error("fail"))
    }

    @Test("UnavailableReason error with different messages are not equal") func error_differentMessages_areNotEqual() {
        #expect(UnavailableReason.error("a") != UnavailableReason.error("b"))
    }

    @Test("Different UnavailableReason cases are not equal") func differentCases_areNotEqual() {
        #expect(UnavailableReason.noAccount != UnavailableReason.restricted)
        #expect(UnavailableReason.restricted != UnavailableReason.couldNotDetermine)
        #expect(UnavailableReason.couldNotDetermine != UnavailableReason.temporarilyUnavailable)
        #expect(UnavailableReason.temporarilyUnavailable != UnavailableReason.error("test"))
    }
}
