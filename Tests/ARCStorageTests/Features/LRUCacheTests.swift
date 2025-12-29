import Testing
@testable import ARCStorage

@Suite("LRUCache Tests")
struct LRUCacheTests {
    @Test("Basic set and get works correctly")
    func basicSetAndGet_worksCorrectly() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")
        await cache.set(3, for: "three")

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let value3 = await cache.get("three")

        #expect(value1 == 1)
        #expect(value2 == 2)
        #expect(value3 == 3)
    }

    @Test("Capacity eviction removes oldest entry")
    func capacityEviction_removesOldestEntry() async {
        let cache = LRUCache<String, Int>(capacity: 2)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")
        await cache.set(3, for: "three") // Should evict "one"

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let value3 = await cache.get("three")

        #expect(value1 == nil)
        #expect(value2 == 2)
        #expect(value3 == 3)
    }

    @Test("LRU ordering preserves recently accessed")
    func lruOrdering_preservesRecentlyAccessed() async {
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

        #expect(value1 == 1)
        #expect(value2 == nil)
        #expect(value3 == 3)
    }

    @Test("Update replaces existing value")
    func update_replacesExistingValue() async {
        let cache = LRUCache<String, Int>(capacity: 2)

        await cache.set(1, for: "one")
        await cache.set(2, for: "one") // Update

        let value = await cache.get("one")
        #expect(value == 2)
    }

    @Test("Remove deletes specific entry")
    func remove_deletesSpecificEntry() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")

        await cache.remove("one")

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")

        #expect(value1 == nil)
        #expect(value2 == 2)
    }

    @Test("Clear removes all entries")
    func clear_removesAllEntries() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")

        await cache.clear()

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")
        let count = await cache.count

        #expect(value1 == nil)
        #expect(value2 == nil)
        #expect(count == .zero)
    }
}
