import Testing
@testable import ARCStorage

@Suite("CachePolicy Tests")
struct CachePolicyTests {
    @Test("Default policy has correct values")
    func defaultPolicy_hasCorrectValues() {
        let policy = CachePolicy.default

        #expect(policy.ttl == 300)
        #expect(policy.maxSize == 100)
        #expect(policy.strategy == .lru)
    }

    @Test("Aggressive policy has correct values")
    func aggressivePolicy_hasCorrectValues() {
        let policy = CachePolicy.aggressive

        #expect(policy.ttl == 3600)
        #expect(policy.maxSize == 500)
        #expect(policy.strategy == .lru)
    }

    @Test("NoCache policy has correct values")
    func noCachePolicy_hasCorrectValues() {
        let policy = CachePolicy.noCache

        #expect(policy.ttl == 0)
        #expect(policy.maxSize == 0)
        #expect(policy.strategy == .lru)
    }

    @Test("Custom policy preserves values")
    func customPolicy_preservesValues() {
        let policy = CachePolicy(ttl: 600, maxSize: 200, strategy: .fifo)

        #expect(policy.ttl == 600)
        #expect(policy.maxSize == 200)
        #expect(policy.strategy == .fifo)
    }
}
