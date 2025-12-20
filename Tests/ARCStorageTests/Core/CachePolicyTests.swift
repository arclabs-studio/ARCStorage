import XCTest
@testable import ARCStorage

final class CachePolicyTests: XCTestCase {
    func testDefaultPolicy() {
        let policy = CachePolicy.default

        XCTAssertEqual(policy.ttl, 300)
        XCTAssertEqual(policy.maxSize, 100)
        XCTAssertEqual(policy.strategy, .lru)
    }

    func testAggressivePolicy() {
        let policy = CachePolicy.aggressive

        XCTAssertEqual(policy.ttl, 3600)
        XCTAssertEqual(policy.maxSize, 500)
        XCTAssertEqual(policy.strategy, .lru)
    }

    func testNoCachePolicy() {
        let policy = CachePolicy.noCache

        XCTAssertEqual(policy.ttl, 0)
        XCTAssertEqual(policy.maxSize, 0)
        XCTAssertEqual(policy.strategy, .lru)
    }

    func testCustomPolicy() {
        let policy = CachePolicy(ttl: 600, maxSize: 200, strategy: .fifo)

        XCTAssertEqual(policy.ttl, 600)
        XCTAssertEqual(policy.maxSize, 200)
        XCTAssertEqual(policy.strategy, .fifo)
    }
}
