//
//  PhotoDemoViewModel.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 18/3/26.
//

import ARCStorage
import Foundation
import SwiftData
import SwiftUI

/// ViewModel demonstrating `SwiftDataPhotoRepository` and `ARCPhoto` persistence.
///
/// Shows how to:
/// - Create a `SwiftDataPhotoRepository` from a shared `ModelContainer`
/// - Add, display, and delete `ARCPhoto` entities
/// - Generate synthetic image data for demo purposes
@MainActor
@Observable
final class PhotoDemoViewModel {
    // MARK: Properties

    private(set) var photos: [ARCPhoto] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let photoRepository: SwiftDataPhotoRepository
    private let modelContext: ModelContext

    // MARK: Initialization

    init(modelContainer: ModelContainer) {
        photoRepository = SwiftDataPhotoRepository(modelContainer: modelContainer)
        modelContext = modelContainer.mainContext
    }

    // MARK: Actions

    /// Loads all stored photos.
    func loadPhotos() {
        isLoading = true
        errorMessage = nil
        do {
            photos = try modelContext.fetch(FetchDescriptor<ARCPhoto>(sortBy: [SortDescriptor(\.sortOrder)]))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Adds a synthetic coloured-block JPEG photo.
    ///
    /// `photoRepository.add` is `async` — thumbnail generation runs off the main thread
    /// via actor-hop. A `Task` bridges the synchronous call site to the async API.
    func addSamplePhoto() {
        errorMessage = nil
        let sortOrder = photos.count
        let data = Self.solidColorJPEG(paletteColors[sortOrder % paletteColors.count])
        Task {
            do {
                _ = try await photoRepository.add(imageData: data,
                                                  caption: "Sample \(sortOrder + 1)",
                                                  sortOrder: sortOrder)
                loadPhotos()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Deletes a photo by its persistent identifier.
    func deletePhoto(_ photo: ARCPhoto) {
        errorMessage = nil
        do {
            try photoRepository.delete(id: photo.persistentModelID)
            loadPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes all stored photos.
    func clearAll() {
        errorMessage = nil
        do {
            try photoRepository.deleteAll(photos)
            loadPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Synthetic Image Generation

    private static let paletteColors: [Color] = [.blue, .purple, .orange, .green, .red, .teal, .pink, .indigo]
    private var paletteColors: [Color] {
        Self.paletteColors
    }

    #if canImport(UIKit)
    private static func solidColorJPEG(_ color: Color) -> Data {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(color).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    #else
    private static func solidColorJPEG(_: Color) -> Data {
        Data()
    }
    #endif
}
