import XCTest
@testable import ARCStorage

final class LRUCacheTests: XCTestCase {
    func testBasicSetAndGet() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")
        await cache.set(3, for: "three")

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let value3 = await cache.get("three")

        XCTAssertEqual(value1, 1)
        XCTAssertEqual(value2, 2)
        XCTAssertEqual(value3, 3)
    }

    func testCapacityEviction() async {
        let cache = LRUCache<String, Int>(capacity: 2)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")
        await cache.set(3, for: "three") // Should evict "one"

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let value3 = await cache.get("three")

        XCTAssertNil(value1)
        XCTAssertEqual(value2, 2)
        XCTAssertEqual(value3, 3)
    }

    func testLRUOrdering() async {
        let cache = LRUCache<String, Int>(capacity: 2)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")

        // Access "one" to make it recently used
        _ = await cache.get("one")

        // Add "three", should evict "two"
        await cache.set(3, for: "three")

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let value3 = await cache.get("three")

        XCTAssertEqual(value1, 1)
        XCTAssertNil(value2)
        XCTAssertEqual(value3, 3)
    }

    func testUpdate() async {
        let cache = LRUCache<String, Int>(capacity: 2)

        await cache.set(1, for: "one")
        await cache.set(2, for: "one") // Update

        let value = await cache.get("one")
        XCTAssertEqual(value, 2)
    }

    func testRemove() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")

        await cache.remove("one")

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")

        XCTAssertNil(value1)
        XCTAssertEqual(value2, 2)
    }

    func testClear() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")

        await cache.clear()

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let count = await cache.count

        XCTAssertNil(value1)
        XCTAssertNil(value2)
        XCTAssertEqual(count, 0)
    }
}
