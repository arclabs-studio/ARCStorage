import XCTest
@testable import ARCStorage

final class StorageErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let notFoundError = StorageError.notFound(id: "test-id")
        XCTAssertTrue(notFoundError.errorDescription?.contains("test-id") == true)

        let saveError = StorageError.saveFailed(underlying: NSError(domain: "test", code: 1))
        XCTAssertTrue(saveError.errorDescription?.contains("save") == true)

        let fetchError = StorageError.fetchFailed(underlying: NSError(domain: "test", code: 2))
        XCTAssertTrue(fetchError.errorDescription?.contains("fetch") == true)

        let deleteError = StorageError.deleteFailed(underlying: NSError(domain: "test", code: 3))
        XCTAssertTrue(deleteError.errorDescription?.contains("delete") == true)

        let invalidDataError = StorageError.invalidData
        XCTAssertTrue(invalidDataError.errorDescription?.contains("invalid") == true)

        let transactionError = StorageError.transactionFailed(underlying: NSError(domain: "test", code: 4))
        XCTAssertTrue(transactionError.errorDescription?.contains("Transaction") == true)
    }
}
