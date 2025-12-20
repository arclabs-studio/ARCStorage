import XCTest
@testable import ARCStorage

final class CacheManagerTests: XCTestCase {
    func testCacheSetAndGet() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(42, for: "key1")
        let value = await cache.get("key1")

        XCTAssertEqual(value, 42)
    }

    func testCacheExpiration() async throws {
        let shortTTL = CachePolicy(ttl: 0.1, maxSize: 10, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: shortTTL)

        await cache.set(42, for: "key1")

        // Wait for expiration
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let value = await cache.get("key1")
        XCTAssertNil(value)
    }

    func testCacheEviction() async {
        let policy = CachePolicy(ttl: 3600, maxSize: 2, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")
        await cache.set(3, for: "key3") // Should evict key1

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")
        let value3 = await cache.get("key3")

        XCTAssertNil(value1)
        XCTAssertEqual(value2, 2)
        XCTAssertEqual(value3, 3)
    }

    func testCacheLRUOrdering() async {
        let policy = CachePolicy(ttl: 3600, maxSize: 2, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")

        // Access key1 to make it recently used
        _ = await cache.get("key1")

        // Add key3, should evict key2 (least recently used)
        await cache.set(3, for: "key3")

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")
        let value3 = await cache.get("key3")

        XCTAssertEqual(value1, 1)
        XCTAssertNil(value2)
        XCTAssertEqual(value3, 3)
    }

    func testCacheInvalidate() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(42, for: "key1")
        await cache.invalidate("key1")

        let value = await cache.get("key1")
        XCTAssertNil(value)
    }

    func testCacheInvalidateAll() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")
        await cache.invalidate()

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")

        XCTAssertNil(value1)
        XCTAssertNil(value2)
    }

    func testNoCachePolicy() async {
        let cache = CacheManager<String, Int>(policy: .noCache)

        await cache.set(42, for: "key1")
        let value = await cache.get("key1")

        XCTAssertNil(value) // Should not cache
    }
}
