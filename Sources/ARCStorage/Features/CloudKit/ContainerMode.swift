import Foundation
@preconcurrency import SwiftData

/// How a `ModelContainer` ended up being configured.
///
/// Returned by ``SwiftDataConfiguration/makeContainerReportingMode()`` so an app can react when
/// CloudKit sync was requested but is not actually active — for example to warn a premium user
/// that they are not signed in to iCloud.
///
/// ## Example
/// ```swift
/// let result = try await config.makeContainerReportingMode()
/// switch result.mode {
/// case .cloudKit:
///     break
/// case .localOnly:
///     break
/// case let .localFallback(reason):
///     showBanner("iCloud sync unavailable: \(reason)")
/// }
/// ```
public enum ContainerMode: Sendable, Equatable {
    /// CloudKit sync is enabled and the container was created with CloudKit mirroring.
    case cloudKit

    /// CloudKit was never requested — the configuration is local-only by design.
    case localOnly

    /// CloudKit was requested but is unavailable, so a local-only container was created.
    ///
    /// The container uses the same backing store file as the CloudKit configuration,
    /// so no data is lost or hidden while iCloud is unavailable.
    ///
    /// - Parameter reason: Why CloudKit is unavailable.
    case localFallback(reason: UnavailableReason)
}

/// A model container together with the mode it was created in.
///
/// See ``SwiftDataConfiguration/makeContainerReportingMode()``.
public struct ContainerResult: Sendable {
    /// The created model container.
    public let container: ModelContainer

    /// How the container was configured.
    public let mode: ContainerMode

    /// Creates a container result.
    ///
    /// - Parameters:
    ///   - container: The created model container.
    ///   - mode: How the container was configured.
    public init(container: ModelContainer, mode: ContainerMode) {
        self.container = container
        self.mode = mode
    }
}
