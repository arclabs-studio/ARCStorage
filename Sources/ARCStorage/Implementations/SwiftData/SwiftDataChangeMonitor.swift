import Foundation
import SwiftData

/// Monitors SwiftData model context saves and exposes changes as an AsyncStream.
///
/// Observes `ModelContext.didSave` notifications from the container's main context,
/// using Apple's documented pattern for reacting to data changes when `@Query` is
/// not used directly in views (e.g. Clean Architecture / repository pattern apps).
///
/// Multiple consumers are supported — each call to ``changes()`` returns an
/// independent stream backed by its own notification observation.
///
/// The stream automatically terminates when the consuming `Task` is cancelled.
/// SwiftUI's `.task {}` modifier cancels automatically on view disappear, so no
/// manual cleanup is required.
///
/// ## Example
/// ```swift
/// let monitor = SwiftDataChangeMonitor(modelContainer: container)
///
/// // In a ViewModel:
/// func loadAndObserve() async {
///     await loadData()
///     for await _ in monitor.changes() {
///         await loadData()
///     }
/// }
///
/// // In a View:
/// .task { await viewModel.loadAndObserve() }
/// ```
///
/// > Note: This monitor uses `ModelContext.didSave`, which fires after every
/// > successful `save()` on the main context — including saves triggered by
/// > CloudKit sync and background imports.
@MainActor
public final class SwiftDataChangeMonitor {
    // MARK: Private Properties

    private let modelContainer: ModelContainer

    /// Notification observer tokens, keyed per stream. Main-actor isolated like the monitor.
    private var observers: [UUID: any NSObjectProtocol] = [:]

    // MARK: Initialization

    /// Creates a new change monitor for the given model container.
    ///
    /// - Parameter modelContainer: The model container whose main context to observe.
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: Public Methods

    /// Returns an `AsyncStream` that yields `Void` each time the model context saves.
    ///
    /// Each call creates an independent stream — call this multiple times for multiple
    /// independent consumers. The stream finishes when the consuming `Task` is cancelled.
    ///
    /// - Returns: An `AsyncStream<Void>` that yields on every `ModelContext.didSave`.
    public func changes() -> AsyncStream<Void> {
        // Capture the context's ObjectIdentifier (a Sendable value) rather than
        // the ModelContext itself (non-Sendable). This filters notifications to the
        // correct context without violating Swift 6 strict concurrency.
        //
        // Uses the callback-based addObserver API for immediate, synchronous delivery —
        // more reliable than the async notifications() sequence in environments
        // without a spinning run loop (e.g., Swift Testing). Follows the same
        // pattern as CloudKitSyncMonitor.
        let contextID = ObjectIdentifier(modelContainer.mainContext)
        let observerID = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream()

        observers[observerID] = NotificationCenter.default.addObserver(forName: ModelContext.didSave,
                                                                       object: nil,
                                                                       queue: .main) { notification in
            guard let context = notification.object as? ModelContext,
                  ObjectIdentifier(context) == contextID else { return }
            continuation.yield()
        }

        // The token stays on the main actor; termination hops back there to remove it.
        continuation.onTermination = { _ in
            Task { @MainActor in
                self.removeObserver(observerID)
            }
        }

        return stream
    }

    // MARK: Private Methods

    private func removeObserver(_ observerID: UUID) {
        if let token = observers.removeValue(forKey: observerID) {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
