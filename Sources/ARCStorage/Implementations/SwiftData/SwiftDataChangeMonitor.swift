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
    // MARK: Private Types

    /// Boxes an `NSObjectProtocol` observer token so it can safely cross
    /// `@Sendable` closure boundaries in Swift 6 strict concurrency.
    ///
    /// The box is `@unchecked Sendable` because the token is only ever
    /// accessed on the main queue (both registration and removal happen
    /// on `.main`), making concurrent access impossible at runtime.
    private final class TokenBox: @unchecked Sendable {
        var token: (any NSObjectProtocol)?
    }

    // MARK: Private Properties

    private let modelContainer: ModelContainer

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
        let box = TokenBox()

        return AsyncStream { continuation in
            box.token = NotificationCenter.default.addObserver(forName: ModelContext.didSave,
                                                               object: nil,
                                                               queue: .main) { notification in
                guard let context = notification.object as? ModelContext,
                      ObjectIdentifier(context) == contextID else { return }
                continuation.yield()
            }

            continuation.onTermination = { _ in
                if let token = box.token {
                    NotificationCenter.default.removeObserver(token)
                    box.token = nil
                }
            }
        }
    }
}
