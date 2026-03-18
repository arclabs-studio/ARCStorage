//
//  PhotoDemoView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 18/3/26.
//

import ARCStorage
import SwiftData
import SwiftUI

/// Demonstrates `SwiftDataPhotoRepository` and `ARCPhoto` persistence.
///
/// Shows how to add, list, and delete photo attachments via `PhotoRepository`.
struct PhotoDemoView: View {
    // MARK: Properties

    @State private var viewModel: PhotoDemoViewModel

    // MARK: Initialization

    init(viewModel: PhotoDemoViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading photos...")
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.photos.isEmpty {
                    emptyView
                } else {
                    photoGrid
                }
            }
            .navigationTitle("Photos (ARCPhoto)")
            .toolbar {
                toolbarContent
            }
            .onAppear {
                viewModel.loadPhotos()
            }
        }
    }
}

// MARK: - Subviews

extension PhotoDemoView {
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140))], spacing: 4) {
                ForEach(viewModel.photos) { photo in
                    photoCell(photo)
                }
            }
            .padding()

            infoFooter
                .padding(.horizontal)
                .padding(.bottom)
        }
    }

    private func photoCell(_ photo: ARCPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            thumbnailView(photo)

            Button {
                viewModel.deletePhoto(photo)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .padding(4)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func thumbnailView(_ photo: ARCPhoto) -> some View {
        Group {
            if let data = photo.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Photos", systemImage: "photo.on.rectangle")
        } description: {
            Text("Tap + to add synthetic demo photos using SwiftDataPhotoRepository.")
        } actions: {
            Button("Add Sample Photo") {
                viewModel.addSamplePhoto()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") { viewModel.loadPhotos() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var infoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How it works", systemImage: "info.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("""
            Each photo is stored as an `ARCPhoto` SwiftData entity:
            • **thumbnailData** — inline JPEG ≤ 200×200 px (fast list rendering)
            • **imageData** — full-size via `@Attribute(.externalStorage)` (CKAsset-ready)

            `SwiftDataPhotoRepository.add()` generates the thumbnail automatically \
            using `ThumbnailGenerator`.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.addSamplePhoto()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add Sample Photo")
        }

        ToolbarItem(placement: .secondaryAction) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAll()
            }
            .disabled(viewModel.photos.isEmpty)
        }
    }
}

// MARK: - Preview

#Preview("With Photos") {
    // swiftlint:disable:next no_force_try force_try
    let container = try! ModelContainer(for: ARCPhoto.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let viewModel = PhotoDemoViewModel(modelContainer: container)
    return PhotoDemoView(viewModel: viewModel)
        .onAppear {
            viewModel.addSamplePhoto()
            viewModel.addSamplePhoto()
            viewModel.addSamplePhoto()
        }
}

#Preview("Empty State") {
    // swiftlint:disable:next no_force_try force_try
    let container = try! ModelContainer(for: ARCPhoto.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let viewModel = PhotoDemoViewModel(modelContainer: container)
    return PhotoDemoView(viewModel: viewModel)
}
