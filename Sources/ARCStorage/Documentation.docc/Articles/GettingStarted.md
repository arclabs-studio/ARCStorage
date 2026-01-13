# Getting Started

Learn how to integrate ARCStorage into your iOS app.

## Overview

ARCStorage provides a flexible persistence layer that adapts to your app's needs. This guide walks through basic integration and common patterns.

## Installation

### Swift Package Manager

Add ARCStorage to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCStorage.git", from: "1.0.0")
]
```

Or add via Xcode: **File → Add Package Dependencies**

## Define Your Model

For SwiftData, your model must conform to `PersistentModel`, `Identifiable`, `Codable`, and `Sendable`:

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

## Configure Storage

In your app initialization:

```swift
import SwiftUI
import SwiftData
import ARCStorage

@main
struct MyApp: App {
    let container: ModelContainer

    init() {
        let config = SwiftDataConfiguration(
            schema: Schema([Restaurant.self]),
            isCloudKitEnabled: true
        )
        container = try! config.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

## Create Repository

```swift
actor RestaurantRepository {
    private let repository: SwiftDataRepository<Restaurant>

    init(modelContainer: ModelContainer) {
        let storage = SwiftDataStorage<Restaurant>(modelContainer: modelContainer)
        self.repository = SwiftDataRepository(storage: storage)
    }

    func fetchAll() async throws -> [Restaurant] {
        try await repository.fetchAll()
    }

    func save(_ restaurant: Restaurant) async throws {
        try await repository.save(restaurant)
    }
}
```

## Use in ViewModel

```swift
import ARCLogger

@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    private let repository: RestaurantRepository
    private let logger = ARCLogger(category: "RestaurantsViewModel")

    init(repository: RestaurantRepository) {
        self.repository = repository
    }

    func loadRestaurants() async {
        do {
            restaurants = try await repository.fetchAll()
            logger.info("Loaded restaurants", metadata: [
                "count": .public(String(restaurants.count))
            ])
        } catch {
            logger.error("Failed to load restaurants", metadata: [
                "error": .public(error.localizedDescription)
            ])
        }
    }
}
```

## Next Steps

- <doc:SwiftDataIntegration> - Deep dive into SwiftData features
- <doc:RepositoryPattern> - Understand the architecture
- <doc:Testing> - Write tests for your repositories
