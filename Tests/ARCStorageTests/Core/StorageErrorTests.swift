import Foundation
import Testing
@testable import ARCStorage

@Suite("StorageError Tests")
struct StorageErrorTests {
    @Test("notFound error description contains ID")
    func notFoundError_containsId() {
        let error = StorageError.notFound(id: "test-id")
        #expect(error.errorDescription?.contains("test-id") == true)
    }

    @Test("saveFailed error description contains save")
    func saveFailedError_containsSave() {
        let error = StorageError.saveFailed(underlying: NSError(domain: "test", code: 1))
        #expect(error.errorDescription?.contains("save") == true)
    }

    @Test("fetchFailed error description contains fetch")
    func fetchFailedError_containsFetch() {
        let error = StorageError.fetchFailed(underlying: NSError(domain: "test", code: 2))
        #expect(error.errorDescription?.contains("fetch") == true)
    }

    @Test("deleteFailed error description contains delete")
    func deleteFailedError_containsDelete() {
        let error = StorageError.deleteFailed(underlying: NSError(domain: "test", code: 3))
        #expect(error.errorDescription?.contains("delete") == true)
    }

    @Test("invalidData error description contains invalid")
    func invalidDataError_containsInvalid() {
        let error = StorageError.invalidData
        #expect(error.errorDescription?.contains("invalid") == true)
    }

    @Test("transactionFailed error description contains Transaction")
    func transactionFailedError_containsTransaction() {
        let error = StorageError.transactionFailed(underlying: NSError(domain: "test", code: 4))
        #expect(error.errorDescription?.contains("Transaction") == true)
    }
}
