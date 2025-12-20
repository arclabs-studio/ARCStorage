import SwiftUI
import SwiftData
import ARCStorage

/// Example restaurant app showcasing ARCStorage usage.
///
/// This is a complete working example demonstrating:
/// - Model definition
/// - Repository pattern
/// - ViewModel with dependency injection
/// - SwiftUI integration
/// - Testing approach

// MARK: - Model

@Model
final class Restaurant: Identifiable, Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var cuisine: String
    var rating: Double
    var isFavorite: Bool
    var address: String

    init(
        id: UUID = UUID(),
        name: String,
        cuisine: String,
        rating: Double,
        isFavorite: Bool = false,
        address: String
    ) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.rating = rating
        self.isFavorite = isFavorite
        self.address = address
    }
}

// MARK: - Repository Protocol

protocol RestaurantRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Restaurant]
    func fetch(id: UUID) async throws -> Restaurant?
    func fetchFavorites() async throws -> [Restaurant]
    func fetchByCuisine(_ cuisine: String) async throws -> [Restaurant]
    func fetchHighRated(minimumRating: Double) async throws -> [Restaurant]
    func save(_ restaurant: Restaurant) async throws
    func delete(id: UUID) async throws
}

// MARK: - Repository Implementation

actor RestaurantRepository: RestaurantRepositoryProtocol {
    private let storage: SwiftDataRepository<Restaurant>

    init(modelContainer: ModelContainer) {
        let swiftDataStorage = SwiftDataStorage<Restaurant>(modelContainer: modelContainer)
        self.storage = SwiftDataRepository(
            storage: swiftDataStorage,
            cachePolicy: .default
        )
    }

    func fetchAll() async throws -> [Restaurant] {
        try await storage.fetchAll()
    }

    func fetch(id: UUID) async throws -> Restaurant? {
        try await storage.fetch(id: id)
    }

    func fetchFavorites() async throws -> [Restaurant] {
        let predicate = #Predicate<Restaurant> { $0.isFavorite == true }
        return try await storage.fetch(matching: predicate)
    }

    func fetchByCuisine(_ cuisine: String) async throws -> [Restaurant] {
        let predicate = #Predicate<Restaurant> { $0.cuisine == cuisine }
        return try await storage.fetch(matching: predicate)
    }

    func fetchHighRated(minimumRating: Double) async throws -> [Restaurant] {
        let predicate = #Predicate<Restaurant> { $0.rating >= minimumRating }
        return try await storage.fetch(matching: predicate)
    }

    func save(_ restaurant: Restaurant) async throws {
        try await storage.save(restaurant)
    }

    func delete(id: UUID) async throws {
        try await storage.delete(id: id)
    }
}

// MARK: - ViewModel

@MainActor
final class RestaurantsViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var favorites: [Restaurant] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let repository: any RestaurantRepositoryProtocol

    init(repository: any RestaurantRepositoryProtocol) {
        self.repository = repository
    }

    func loadRestaurants() async {
        isLoading = true
        defer { isLoading = false }

        do {
            restaurants = try await repository.fetchAll()
            error = nil
        } catch {
            self.error = error
        }
    }

    func loadFavorites() async {
        do {
            favorites = try await repository.fetchFavorites()
        } catch {
            self.error = error
        }
    }

    func toggleFavorite(_ restaurant: Restaurant) async {
        var updated = restaurant
        updated.isFavorite.toggle()

        do {
            try await repository.save(updated)
            await loadRestaurants()
            await loadFavorites()
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

    func deleteRestaurant(id: UUID) async {
        do {
            try await repository.delete(id: id)
            await loadRestaurants()
        } catch {
            self.error = error
        }
    }
}

// MARK: - SwiftUI Views

struct RestaurantsListView: View {
    @StateObject private var viewModel: RestaurantsViewModel

    init(repository: any RestaurantRepositoryProtocol) {
        _viewModel = StateObject(
            wrappedValue: RestaurantsViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.error {
                    ErrorView(error: error)
                } else {
                    List {
                        ForEach(viewModel.restaurants) { restaurant in
                            RestaurantRowView(
                                restaurant: restaurant,
                                onFavoriteToggle: {
                                    await viewModel.toggleFavorite(restaurant)
                                }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let restaurant = viewModel.restaurants[index]
                                await viewModel.deleteRestaurant(id: restaurant.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Restaurants")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        // Show add restaurant sheet
                    }
                }
            }
            .task {
                await viewModel.loadRestaurants()
            }
        }
    }
}

struct RestaurantRowView: View {
    let restaurant: Restaurant
    let onFavoriteToggle: () async -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)

                Text(restaurant.cuisine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(restaurant.rating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
            }

            Spacer()

            Button(action: {
                Task {
                    await onFavoriteToggle()
                }
            }) {
                Image(systemName: restaurant.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(restaurant.isFavorite ? .red : .gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - App

@main
struct RestaurantApp: App {
    let modelContainer: ModelContainer
    let repository: RestaurantRepository

    init() {
        let config = SwiftDataConfiguration(
            schema: Schema([Restaurant.self]),
            isCloudKitEnabled: true
        )

        do {
            modelContainer = try config.makeContainer()
            repository = RestaurantRepository(modelContainer: modelContainer)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RestaurantsListView(repository: repository)
                .modelContainer(modelContainer)
        }
    }
}

// MARK: - Testing

#if DEBUG

import XCTest

final class RestaurantsViewModelTests: XCTestCase {
    func testLoadRestaurants() async throws {
        // Given
        let mockRepo = MockRestaurantRepository()
        mockRepo.mockRestaurants = [
            Restaurant(
                id: UUID(),
                name: "Test Restaurant",
                cuisine: "Italian",
                rating: 4.5,
                address: "123 Main St"
            )
        ]

        let viewModel = RestaurantsViewModel(repository: mockRepo)

        // When
        await viewModel.loadRestaurants()

        // Then
        XCTAssertEqual(viewModel.restaurants.count, 1)
        XCTAssertEqual(viewModel.restaurants.first?.name, "Test Restaurant")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testToggleFavorite() async throws {
        // Given
        let mockRepo = MockRestaurantRepository()
        let restaurant = Restaurant(
            id: UUID(),
            name: "Test",
            cuisine: "Italian",
            rating: 4.0,
            isFavorite: false,
            address: "123 Main St"
        )
        mockRepo.mockRestaurants = [restaurant]

        let viewModel = RestaurantsViewModel(repository: mockRepo)
        await viewModel.loadRestaurants()

        // When
        await viewModel.toggleFavorite(restaurant)

        // Then
        XCTAssertEqual(mockRepo.saveCallCount, 1)
        XCTAssertTrue(mockRepo.lastSavedRestaurant?.isFavorite == true)
    }
}

actor MockRestaurantRepository: RestaurantRepositoryProtocol {
    var mockRestaurants: [Restaurant] = []
    var saveCallCount = 0
    var lastSavedRestaurant: Restaurant?

    func fetchAll() async throws -> [Restaurant] {
        mockRestaurants
    }

    func fetch(id: UUID) async throws -> Restaurant? {
        mockRestaurants.first { $0.id == id }
    }

    func fetchFavorites() async throws -> [Restaurant] {
        mockRestaurants.filter { $0.isFavorite }
    }

    func fetchByCuisine(_ cuisine: String) async throws -> [Restaurant] {
        mockRestaurants.filter { $0.cuisine == cuisine }
    }

    func fetchHighRated(minimumRating: Double) async throws -> [Restaurant] {
        mockRestaurants.filter { $0.rating >= minimumRating }
    }

    func save(_ restaurant: Restaurant) async throws {
        saveCallCount += 1
        lastSavedRestaurant = restaurant

        if let index = mockRestaurants.firstIndex(where: { $0.id == restaurant.id }) {
            mockRestaurants[index] = restaurant
        } else {
            mockRestaurants.append(restaurant)
        }
    }

    func delete(id: UUID) async throws {
        mockRestaurants.removeAll { $0.id == id }
    }
}

#endif
