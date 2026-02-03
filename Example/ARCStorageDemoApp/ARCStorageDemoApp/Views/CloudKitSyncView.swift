//
//  CloudKitSyncView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 03/02/2026.
//

import ARCStorage
import SwiftUI

/// Demonstrates CloudKit synchronization monitoring using ARCStorage.
///
/// This view shows how to:
/// - Monitor sync status using `CloudKitSyncMonitor`
/// - Display sync state with visual indicators
/// - Trigger manual sync operations
/// - Show CloudKit model requirements
struct CloudKitSyncView: View {
    // MARK: Properties

    @State private var monitor = CloudKitSyncMonitor()
    @State private var showingRequirements = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                syncStatusSection
                actionsSection
                requirementsSection
            }
            .navigationTitle("CloudKit Sync")
            .task {
                await monitor.startMonitoring()
            }
            .sheet(isPresented: $showingRequirements) {
                CloudKitRequirementsSheet()
            }
        }
    }

    // MARK: Sections

    private var syncStatusSection: some View {
        Section("Sync Status") {
            HStack {
                statusIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.status.description)
                        .font(.headline)
                    if let lastSync = monitor.lastSyncDate {
                        Text("Last sync: \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            if monitor.status.hasError, let error = monitor.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                Task {
                    try? await monitor.triggerSync()
                }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(monitor.status.isSyncing || !monitor.isActive)

            Button {
                showingRequirements = true
            } label: {
                Label("View CloudKit Requirements", systemImage: "doc.text")
            }
        }
    }

    private var requirementsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("CloudKit Model Checklist")
                    .font(.headline)

                RequirementRow(
                    icon: "checkmark.circle.fill",
                    text: "All properties have defaults or are optional",
                    color: .green
                )
                RequirementRow(
                    icon: "checkmark.circle.fill",
                    text: "All relationships are optional",
                    color: .green
                )
                RequirementRow(
                    icon: "checkmark.circle.fill",
                    text: "@Attribute(.unique) on id property",
                    color: .green
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Model Requirements")
        } footer: {
            Text("PersistentNote model follows all CloudKit best practices.")
        }
    }

    // MARK: Status Icon

    @ViewBuilder private var statusIcon: some View {
        switch monitor.status {
        case .idle:
            Image(systemName: "cloud")
                .foregroundStyle(.secondary)
                .font(.title2)
        case .syncing:
            ProgressView()
                .controlSize(.regular)
        case .synced:
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(.green)
                .font(.title2)
        case .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundStyle(.red)
                .font(.title2)
        }
    }
}

// MARK: - RequirementRow

private struct RequirementRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - CloudKitRequirementsSheet

private struct CloudKitRequirementsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    requirementSection(
                        title: "Property Requirements",
                        description: """
                        All properties must be optional OR have default values. \
                        CloudKit sync can create partial objects during sync conflicts.
                        """,
                        code: """
                        @Model
                        final class Note: SwiftDataEntity {
                            @Attribute(.unique)
                            var id: UUID = UUID()     // Has default
                            var title: String = ""    // Has default
                            var content: String?      // Optional
                        }
                        """
                    )

                    requirementSection(
                        title: "Relationship Requirements",
                        description: """
                        All relationships must be optional. CloudKit cannot guarantee \
                        that related objects will sync simultaneously.
                        """,
                        code: """
                        @Model
                        final class Note: SwiftDataEntity {
                            // ...
                            @Relationship(deleteRule: .cascade)
                            var tags: [Tag]?  // Optional
                        }
                        """
                    )

                    requirementSection(
                        title: "Index for Fast Lookups",
                        description: """
                        Use @Attribute(.unique) on your id property to create a database \
                        index for O(1) lookups instead of O(n) table scans.
                        """,
                        code: """
                        @Model
                        final class Note: SwiftDataEntity {
                            @Attribute(.unique)  // Creates index
                            var id: UUID = UUID()
                        }
                        """
                    )
                }
                .padding()
            }
            .navigationTitle("CloudKit Requirements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func requirementSection(title: String, description: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview

#Preview {
    CloudKitSyncView()
}
