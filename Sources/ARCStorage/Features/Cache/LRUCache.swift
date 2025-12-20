import Foundation

/// Specialized LRU (Least Recently Used) cache implementation.
///
/// This cache automatically evicts the least recently accessed items
/// when capacity is reached.
///
/// ## Example
/// ```swift
/// let cache = LRUCache<String, Data>(capacity: 50)
/// await cache.set(data, for: "key")
/// let value = await cache.get("key")
/// ```
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private var cache: [Key: Node<Key, Value>] = [:]
    private var head: Node<Key, Value>?
    private var tail: Node<Key, Value>?
    private let capacity: Int
    private var currentSize: Int = 0

    /// Creates a new LRU cache.
    ///
    /// - Parameter capacity: Maximum number of items to cache
    public init(capacity: Int) {
        self.capacity = capacity
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
    /// If capacity is reached, removes the least recently used item.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The key to associate with the value
    public func set(_ value: Value, for key: Key) {
        if let existingNode = cache[key] {
            existingNode.value = value
            moveToHead(existingNode)
        } else {
            let newNode = Node(key: key, value: value)
            cache[key] = newNode
            addToHead(newNode)
            currentSize += 1

            if currentSize > capacity {
                removeTail()
            }
        }
    }

    /// Removes a specific entry.
    ///
    /// - Parameter key: The key to remove
    public func remove(_ key: Key) {
        guard let node = cache[key] else { return }
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
    }

    /// Current number of cached items.
    public var count: Int {
        currentSize
    }

    // MARK: - Private Methods

    private func addToHead(_ node: Node<Key, Value>) {
        node.next = head
        node.prev = nil

        if let head = head {
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
        guard let tail = tail else { return }
        cache.removeValue(forKey: tail.key)
        removeNode(tail)
        currentSize -= 1
    }
}

/// Internal node for doubly-linked list in LRU cache.
private class Node<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    let key: Key
    var value: Value
    var prev: Node?
    var next: Node?

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}
