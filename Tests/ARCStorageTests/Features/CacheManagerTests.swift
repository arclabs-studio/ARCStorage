import Testing
@testable import ARCStorage

@Suite("CacheManager Tests")
struct CacheManagerTests {

    @Test("Set and get works correctly")
    func setAndGet_worksCorrectly() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(42, for: "key1")
        let value = await cache.get("key1")

        #expect(value == 42)
    }

    @Test("Cache expires after TTL")
    func cacheExpiration_afterTTL() async throws {
        let shortTTL = CachePolicy(ttl: 0.1, maxSize: 10, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: shortTTL)

        await cache.set(42, for: "key1")

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        let value = await cache.get("key1")
        #expect(value == nil)
    }

    @Test("Cache evicts when at capacity")
    func cacheEviction_whenAtCapacity() async {
        let policy = CachePolicy(ttl: 3600, maxSize: 2, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")
        await cache.set(3, for: "key3") // Should evict key1

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")
        let value3 = await cache.get("key3")

        #expect(value1 == nil)
        #expect(value2 == 2)
        #expect(value3 == 3)
    }

    @Test("LRU ordering preserves recently used")
    func lruOrdering_preservesRecentlyUsed() async {
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

        #expect(value1 == 1)
        #expect(value2 == nil)
        #expect(value3 == 3)
    }

    @Test("Invalidate removes specific key")
    func invalidate_removesSpecificKey() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(42, for: "key1")
        await cache.invalidate("key1")

        let value = await cache.get("key1")
        #expect(value == nil)
    }

    @Test("Invalidate all removes all entries")
    func invalidateAll_removesAllEntries() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")
        await cache.invalidate()

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")

        #expect(value1 == nil)
        #expect(value2 == nil)
    }

    @Test("NoCache policy does not cache")
    func noCachePolicy_doesNotCache() async {
        let cache = CacheManager<String, Int>(policy: .noCache)

        await cache.set(42, for: "key1")
        let value = await cache.get("key1")

        #expect(value == nil)
    }
}
