import Foundation
import Testing
@testable import ARCStorage

struct LRUCacheTests {
    @Test("Basic set and get works correctly") func basicSetAndGet_worksCorrectly() async {
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

    @Test("Capacity eviction removes oldest entry") func capacityEviction_removesOldestEntry() async {
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

    @Test("LRU ordering preserves recently accessed") func lruOrdering_preservesRecentlyAccessed() async {
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

    @Test("Update replaces existing value") func update_replacesExistingValue() async {
        let cache = LRUCache<String, Int>(capacity: 2)

        await cache.set(1, for: "one")
        await cache.set(2, for: "one") // Update

        let value = await cache.get("one")
        #expect(value == 2)
    }

    @Test("Remove deletes specific entry") func remove_deletesSpecificEntry() async {
        let cache = LRUCache<String, Int>(capacity: 3)

        await cache.set(1, for: "one")
        await cache.set(2, for: "two")

        await cache.remove("one")

        let value1 = await cache.get("one")
        let value2 = await cache.get("two")

        #expect(value1 == nil)
        #expect(value2 == 2)
    }

    @Test("Clear removes all entries") func clear_removesAllEntries() async {
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

    // MARK: - Byte-Size Eviction Tests

    @Test("Byte-size eviction removes LRU items when limit exceeded") func byteSizeEviction_removesLRUItems() async {
        // Given — 100 byte limit
        let cache = LRUCache<String, Data>(capacity: 100, maxByteSize: 100)

        // When — add 60 bytes, then 60 more
        let data60 = Data(repeating: 0xAA, count: 60)
        await cache.set(data60, for: "a")
        await cache.set(data60, for: "b") // should evict "a"

        // Then
        let valueA = await cache.get("a")
        let valueB = await cache.get("b")
        let bytes = await cache.currentByteSizeUsed

        #expect(valueA == nil)
        #expect(valueB != nil)
        #expect(bytes == 60)
    }

    @Test("Byte-size tracking reports correct size") func byteSizeTracking_reportsCorrectSize() async {
        // Given
        let cache = LRUCache<String, Data>(capacity: 100, maxByteSize: 10000)

        // When
        await cache.set(Data(repeating: 0x01, count: 100), for: "a")
        await cache.set(Data(repeating: 0x02, count: 200), for: "b")

        // Then
        let bytes = await cache.currentByteSizeUsed
        #expect(bytes == 300)
    }

    @Test("Byte-size updates on value replacement") func byteSizeUpdate_onReplacement() async {
        // Given
        let cache = LRUCache<String, Data>(capacity: 100, maxByteSize: 10000)

        // When — set 100 bytes, then replace with 50
        await cache.set(Data(repeating: 0x01, count: 100), for: "a")
        await cache.set(Data(repeating: 0x02, count: 50), for: "a")

        // Then
        let bytes = await cache.currentByteSizeUsed
        #expect(bytes == 50)
    }
}
