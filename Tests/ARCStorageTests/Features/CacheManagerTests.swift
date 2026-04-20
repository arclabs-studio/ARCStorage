import Foundation
import Testing
@testable import ARCStorage

struct CacheManagerTests {
    @Test("Set and get works correctly") func setAndGet_worksCorrectly() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(42, for: "key1")
        let value = await cache.get("key1")

        #expect(value == 42)
    }

    @Test("Cache expires after TTL") func cacheExpiration_afterTTL() async throws {
        let shortTTL = CachePolicy(ttl: 0.1, maxSize: 10, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: shortTTL)

        await cache.set(42, for: "key1")

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        let value = await cache.get("key1")
        #expect(value == nil)
    }

    @Test("Cache evicts when at capacity") func cacheEviction_whenAtCapacity() async {
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

    @Test("LRU ordering preserves recently used") func lruOrdering_preservesRecentlyUsed() async {
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

    @Test("Invalidate removes specific key") func invalidate_removesSpecificKey() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(42, for: "key1")
        await cache.invalidate("key1")

        let value = await cache.get("key1")
        #expect(value == nil)
    }

    @Test("Invalidate all removes all entries") func invalidateAll_removesAllEntries() async {
        let cache = CacheManager<String, Int>(policy: .default)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")
        await cache.invalidate()

        let value1 = await cache.get("key1")
        let value2 = await cache.get("key2")

        #expect(value1 == nil)
        #expect(value2 == nil)
    }

    @Test("NoCache policy does not cache") func noCachePolicy_doesNotCache() async {
        let cache = CacheManager<String, Int>(policy: .noCache)

        await cache.set(42, for: "key1")
        let value = await cache.get("key1")

        #expect(value == nil)
    }

    // MARK: - Eviction Event Tests

    @Test("Capacity eviction emits event via AsyncStream") func capacityEviction_emitsEvent() async {
        // Given
        let policy = CachePolicy(ttl: 3600, maxSize: 2, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy, registerForMemoryWarnings: false)

        // When — collect first event
        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")
        await cache.set(3, for: "key3") // triggers eviction of key1

        // Then — verify via stream
        var events: [CacheEvictionEvent<String>] = []
        for await event in cache.evictionEvents {
            events.append(event)
            break // take first event only
        }

        #expect(events.count == 1)
        #expect(events.first?.evictedKeys == ["key1"])
        #expect(events.first?.remainingCount == 1) // key2 remains; key3 inserted after eviction
        if case .capacityLimit = events.first?.reason {} else {
            Issue.record("Expected capacityLimit reason")
        }
    }

    @Test("Memory pressure eviction emits event") func memoryPressure_emitsEvent() async {
        // Given
        let policy = CachePolicy(ttl: 3600, maxSize: 100, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy, registerForMemoryWarnings: false)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")

        // When
        await cache.handleMemoryPressure(level: .warning)

        // Then
        var events: [CacheEvictionEvent<String>] = []
        for await event in cache.evictionEvents {
            events.append(event)
            break
        }

        #expect(events.count == 1)
        if case .memoryPressure(.warning) = events.first?.reason {} else {
            Issue.record("Expected memoryPressure(.warning) reason")
        }
    }

    // MARK: - Byte-Size Eviction Tests

    @Test("Cache evicts by byte size when maxByteSize is set") func byteSizeEviction_evictsWhenExceeded() async {
        // Given — 100 byte limit
        let policy = CachePolicy(ttl: 3600, maxSize: 1000, maxByteSize: 100, strategy: .lru)
        let cache = CacheManager<String, Data>(policy: policy, registerForMemoryWarnings: false)

        // When — add 60 bytes, then 60 more (exceeds 100)
        let data60 = Data(repeating: 0xAA, count: 60)
        await cache.set(data60, for: "a")
        await cache.set(data60, for: "b") // should evict "a"

        // Then
        let valueA = await cache.get("a")
        let valueB = await cache.get("b")
        let byteSize = await cache.currentByteSizeUsed

        #expect(valueA == nil)
        #expect(valueB != nil)
        #expect(byteSize == 60)
    }

    @Test("Byte size tracking is zero for non-ByteSizable values") func byteSizeTracking_zeroForNonByteSizable() async {
        // Given
        let policy = CachePolicy(ttl: 3600, maxSize: 100, maxByteSize: 1000, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy, registerForMemoryWarnings: false)

        // When
        await cache.set(42, for: "key1")
        await cache.set(99, for: "key2")

        // Then
        let byteSize = await cache.currentByteSizeUsed
        #expect(byteSize == 0)
    }

    @Test("Manual invalidate emits event") func manualInvalidate_emitsEvent() async {
        // Given
        let policy = CachePolicy(ttl: 3600, maxSize: 100, strategy: .lru)
        let cache = CacheManager<String, Int>(policy: policy, registerForMemoryWarnings: false)

        await cache.set(1, for: "key1")
        await cache.set(2, for: "key2")

        // When
        await cache.invalidate()

        // Then
        var events: [CacheEvictionEvent<String>] = []
        for await event in cache.evictionEvents {
            events.append(event)
            break
        }

        #expect(events.count == 1)
        if case .manual = events.first?.reason {} else {
            Issue.record("Expected manual reason")
        }
        #expect(events.first?.remainingCount == 0)
    }
}
