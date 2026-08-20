import CloudKit
import Testing
@testable import ARCStorage

struct ContainerModeTests {
    // MARK: - SyncState.from(CKAccountStatus)

    @Test("Available status maps to available") func from_available_mapsToAvailable() {
        // Then
        #expect(SyncState.from(.available) == .available)
    }

    @Test("No account status maps to noAccount") func from_noAccount_mapsToNoAccount() {
        // Then
        #expect(SyncState.from(.noAccount) == .unavailable(reason: .noAccount))
    }

    @Test("Restricted status maps to restricted") func from_restricted_mapsToRestricted() {
        // Then
        #expect(SyncState.from(.restricted) == .unavailable(reason: .restricted))
    }

    @Test("Could not determine maps to couldNotDetermine") func from_couldNotDetermine_maps() {
        // Then
        #expect(SyncState.from(.couldNotDetermine) == .unavailable(reason: .couldNotDetermine))
    }

    @Test("Temporarily unavailable maps to temporarilyUnavailable") func from_temporarilyUnavailable_maps() {
        // Then
        #expect(SyncState.from(.temporarilyUnavailable) == .unavailable(reason: .temporarilyUnavailable))
    }

    @Test("Unknown status maps to couldNotDetermine") func from_unknownStatus_mapsToCouldNotDetermine() {
        // Given - a raw value outside the known cases
        let unknown = CKAccountStatus(rawValue: 99) ?? .couldNotDetermine

        // Then
        #expect(SyncState.from(unknown) == .unavailable(reason: .couldNotDetermine))
    }

    // MARK: - ContainerMode Equality

    @Test("CloudKit mode equals cloudKit mode") func cloudKit_equalsCloudKit() {
        // Then
        #expect(ContainerMode.cloudKit == ContainerMode.cloudKit)
    }

    @Test("LocalOnly and localFallback are not equal") func localOnly_andLocalFallback_areNotEqual() {
        // Then
        #expect(ContainerMode.localOnly != ContainerMode.localFallback(reason: .noAccount))
    }

    @Test("LocalFallback compares its reason") func localFallback_comparesReason() {
        // Given
        let noAccount = ContainerMode.localFallback(reason: .noAccount)
        let restricted = ContainerMode.localFallback(reason: .restricted)

        // Then
        #expect(noAccount == .localFallback(reason: .noAccount))
        #expect(noAccount != restricted)
    }

    @Test("LocalFallback carries an error message") func localFallback_carriesErrorMessage() {
        // Given
        let mode = ContainerMode.localFallback(reason: .error("boom"))

        // Then
        #expect(mode == .localFallback(reason: .error("boom")))
        #expect(mode != .localFallback(reason: .error("other")))
    }
}
