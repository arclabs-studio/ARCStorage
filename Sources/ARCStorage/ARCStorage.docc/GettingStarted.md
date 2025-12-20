# Getting Started with ARCStorage

Set up ARCStorage in your iOS application.

## Overview

This guide walks you through adding ARCStorage to your project and setting up your first repository.

## Installation

### Swift Package Manager

Add ARCStorage to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCStorage.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version requirements

## Basic Setup

### 1. Define Your Model

For SwiftData, your model must conform to these protocols:
- `PersistentModel` (from SwiftData)
- `Identifiable`
- `Codable`
- `Sendable` (for Swift concurrency)

```swift
import SwiftData

@Model
final class Restaurant: Identifiable, Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var cuisine: String
    var rating: Double

    init(id: UUID = UUID(), name: String, cuisine: String, rating: Double) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.rating = rating
    }
}
```

### 2. Configure Storage in Your App

```swift
import SwiftUI
import SwiftData
import ARCStorage

@main
struct MyApp: App {
    let storageConfig: SwiftDataConfiguration
    let modelContainer: ModelContainer

    init() {
        // Configure SwiftData
        storageConfig = SwiftDataConfiguration(
            schema: Schema([Restaurant.self]),
            isCloudKitEnabled: true  // Optional: Enable iCloud sync
        )

        do {
            modelContainer = try storageConfig.makeContainer()
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
```

### 3. Create a Repository

```swift
import ARCStorage

actor RestaurantRepository {
    private let storage: SwiftDataStorage<Restaurant>
    private let repository: SwiftDataRepository<Restaurant>

    init(modelContainer: ModelContainer) {
        self.storage = SwiftDataStorage(modelContainer: modelContainer)
        self.repository = SwiftDataRepository(
            storage: storage,
            cachePolicy: .default
        )
    }

    func fetchAll() async throws -> [Restaurant] {
        try await repository.fetchAll()
    }

    func save(_ restaurant: Restaurant) async throws {
        try await repository.save(restaurant)
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
```

### 4. Use in a ViewModel

```swift
@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let repository: RestaurantRepository

    init(repository: RestaurantRepository) {
        self.repository = repository
    }

    func loadRestaurants() async {
        isLoading = true
        defer { isLoading = false }

        do {
            restaurants = try await repository.fetchAll()
        } catch {
            self.error = error
        }
    }

    func addRestaurant(_ restaurant: Restaurant) async {
        do {
            try await repository.save(restaurant)
            await loadRestaurants()
        } catch {
            self.error = error
        }
    }
}
```

### 5. Display in SwiftUI

```swift
struct RestaurantsView: View {
    @StateObject private var viewModel: RestaurantsViewModel

    init(repository: RestaurantRepository) {
        _viewModel = StateObject(wrappedValue: RestaurantsViewModel(repository: repository))
    }

    var body: some View {
        List(viewModel.restaurants) { restaurant in
            VStack(alignment: .leading) {
                Text(restaurant.name)
                    .font(.headline)
                Text(restaurant.cuisine)
                    .font(.subheadline)
            }
        }
        .task {
            await viewModel.loadRestaurants()
        }
    }
}
```

## Next Steps

- Learn more about <doc:SwiftDataIntegration>
- Understand the <doc:RepositoryPattern>
- Explore <doc:Testing> strategies

## See Also

- ``SwiftDataConfiguration``
- ``SwiftDataStorage``
- ``SwiftDataRepository``
