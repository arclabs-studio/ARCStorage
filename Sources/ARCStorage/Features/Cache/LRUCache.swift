import Foundation

/// Specialized LRU (Least Recently Used) cache implementation.
///
/// This cache automatically evicts the least recently accessed items
/// when capacity or byte-size limits are reached.
///
/// ## Example
/// ```swift
/// let cache = LRUCache<String, Data>(capacity: 50, maxByteSize: 10_000_000)
/// await cache.set(data, for: "key")
/// let value = await cache.get("key")
/// ```
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private var cache: [Key: Node<Key, Value>] = [:]
    private var head: Node<Key, Value>?
    private var tail: Node<Key, Value>?
    private let capacity: Int
    private let maxByteSize: Int?
    private var currentSize: Int = 0
    private var currentBytes: Int = 0

    /// Creates a new LRU cache.
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of items to cache
    ///   - maxByteSize: Maximum total byte size, or `nil` for no byte limit.
    ///     Only effective when values conform to ``ByteSizable``.
    public init(capacity: Int, maxByteSize: Int? = nil) {
        self.capacity = capacity
        self.maxByteSize = maxByteSize
    }

    /// Retrieves a value and marks it as recently used.
    ///
    /// - Parameter key: The key to look up
    /// - Returns: The cached value if found, `nil` otherwise
    public func get(_ key: Key) -> Value? {
        guard let node = cache[key] else {
            return nil
        }

        moveToHead(node)
        return node.value
    }

    /// Stores a value in the cache.
    ///
    /// If capacity or byte-size limit is reached, removes the least recently used items.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The key to associate with the value
    public func set(_ value: Value, for key: Key) {
        let byteSize = (value as? ByteSizable)?.byteSize ?? 0

        if let existingNode = cache[key] {
            currentBytes -= existingNode.byteSize
            existingNode.value = value
            existingNode.byteSize = byteSize
            currentBytes += byteSize
            moveToHead(existingNode)
        } else {
            let newNode = Node(key: key, value: value, byteSize: byteSize)
            cache[key] = newNode
            addToHead(newNode)
            currentSize += 1
            currentBytes += byteSize

            if currentSize > capacity {
                removeTail()
            }
        }

        // Evict by byte size if needed
        if let maxBytes = maxByteSize, maxBytes > 0 {
            while currentBytes > maxBytes, currentSize > 1 {
                removeTail()
            }
        }
    }

    /// Removes a specific entry.
    ///
    /// - Parameter key: The key to remove
    public func remove(_ key: Key) {
        guard let node = cache[key] else { return }
        currentBytes -= node.byteSize
        removeNode(node)
        cache.removeValue(forKey: key)
        currentSize -= 1
    }

    /// Clears all entries.
    public func clear() {
        cache.removeAll()
        head = nil
        tail = nil
        currentSize = 0
        currentBytes = 0
    }

    /// Current number of cached items.
    public var count: Int {
        currentSize
    }

    /// Current total byte size of cached items.
    ///
    /// Only meaningful when values conform to ``ByteSizable``.
    public var currentByteSizeUsed: Int {
        currentBytes
    }

    // MARK: - Private Methods

    private func addToHead(_ node: Node<Key, Value>) {
        node.next = head
        node.prev = nil

        if let head {
            head.prev = node
        }

        head = node

        if tail == nil {
            tail = node
        }
    }

    private func removeNode(_ node: Node<Key, Value>) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }

        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }
    }

    private func moveToHead(_ node: Node<Key, Value>) {
        removeNode(node)
        addToHead(node)
    }

    private func removeTail() {
        guard let tail else { return }
        currentBytes -= tail.byteSize
        cache.removeValue(forKey: tail.key)
        removeNode(tail)
        currentSize -= 1
    }
}

/// Internal node for doubly-linked list in LRU cache.
private class Node<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    let key: Key
    var value: Value
    var byteSize: Int
    var prev: Node?
    var next: Node?

    init(key: Key, value: Value, byteSize: Int) {
        self.key = key
        self.value = value
        self.byteSize = byteSize
    }
}
