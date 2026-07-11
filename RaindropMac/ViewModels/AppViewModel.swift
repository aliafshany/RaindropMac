// AppViewModel.swift
// Central state management for the app

import Foundation
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var user: User?
    @Published var collections: [RaindropCollection] = []
    @Published var selectedCollectionId: Int = 0 // 0 = All, -1 = Unsorted, -99 = Trash, other = collection id
    @Published var selectedCollection: RaindropCollection?
    @Published var raindrops: [Raindrop] = []
    @Published var searchResults: [Raindrop] = []
    @Published var tags: [RaindropTag] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var showAddSheet = false
    @Published var editingRaindrop: Raindrop?
    @Published var totalCount = 0

    private var currentPage = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] query in
                Task { await self?.performSearch(query: query) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Initial Data
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let userTask = APIService.shared.fetchUser()
            async let collectionsTask = APIService.shared.fetchCollections()
            let (fetchedUser, fetchedCollections) = try await (userTask, collectionsTask)
            user = fetchedUser
            collections = fetchedCollections.sorted { $0.sort ?? 0 < $1.sort ?? 0 }
            await loadAllRaindrops()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load Raindrops
    func loadAllRaindrops(page: Int = 0) async {
        isLoading = true
        do {
            let response = try await APIService.shared.fetchAllRaindrops(page: page)
            if page == 0 {
                raindrops = response.items
            } else {
                raindrops.append(contentsOf: response.items)
            }
            totalCount = response.count
            currentPage = page
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadCollection(id: Int, collection: RaindropCollection? = nil) async {
        selectedCollectionId = id
        selectedCollection = collection
        currentPage = 0
        
        // Ask Stella
        if id == -2 {
            raindrops = []
            totalCount = 0
            return
        }
        
        isLoading = true
        do {
            let response = try await APIService.shared.fetchRaindrops(collectionId: id)
            raindrops = response.items
            totalCount = response.count
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard !isLoading else { return }
        let nextPage = currentPage + 1
        isLoading = true
        do {
            let response: RaindropsResponse
            if let col = selectedCollection {
                response = try await APIService.shared.fetchRaindrops(collectionId: col.id, page: nextPage)
            } else {
                response = try await APIService.shared.fetchAllRaindrops(page: nextPage)
            }
            raindrops.append(contentsOf: response.items)
            currentPage = nextPage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Search
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }
        isSearching = true
        do {
            let response = try await APIService.shared.searchRaindrops(
                query: query,
                collectionId: selectedCollection?.id ?? 0
            )
            searchResults = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Tags
    func loadTags() async {
        do {
            tags = try await APIService.shared.fetchTags(
                collectionId: selectedCollection?.id ?? 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sync
    func sync() async {
        isLoading = true
        // 1. Reload tags and collections (since collections might have changed)
        do {
            async let tagsRes = APIService.shared.fetchTags(collectionId: selectedCollectionId)
            async let colsRes = APIService.shared.fetchCollections()
            
            tags = try await tagsRes
            let cols = try await colsRes
            collections = cols
        } catch {
            errorMessage = error.localizedDescription
        }
        
        // 2. Reload current view
        await loadCollection(id: selectedCollectionId, collection: selectedCollection)
    }

    // MARK: - Create Raindrop
    func addRaindrop(link: String, title: String?, tags: [String]) async {
        do {
            let collectionId = selectedCollection?.id ?? -1
            let newRaindrop = try await APIService.shared.createRaindrop(
                link: link,
                title: title,
                collectionId: collectionId,
                tags: tags
            )
            raindrops.insert(newRaindrop, at: 0)
            totalCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Raindrop
    func updateRaindrop(_ raindrop: Raindrop, link: String, title: String?, collectionId: Int, tags: [String]) async {
        do {
            let updated = try await APIService.shared.updateRaindrop(
                id: raindrop.id,
                link: link,
                title: title,
                collectionId: collectionId,
                tags: tags
            )
            if let idx = raindrops.firstIndex(where: { $0.id == raindrop.id }) {
                raindrops[idx] = updated
            }
            if let idx = searchResults.firstIndex(where: { $0.id == raindrop.id }) {
                searchResults[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Raindrop
    func deleteRaindrop(_ raindrop: Raindrop) async {
        do {
            try await APIService.shared.deleteRaindrop(id: raindrop.id)
            raindrops.removeAll { $0.id == raindrop.id }
            searchResults.removeAll { $0.id == raindrop.id }
            totalCount -= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle Favorite
    func toggleFavorite(_ raindrop: Raindrop) async {
        let newState = !(raindrop.important ?? false)
        do {
            try await APIService.shared.toggleFavorite(id: raindrop.id, important: newState)
            if let idx = raindrops.firstIndex(of: raindrop) {
                // Optimistic update - rebuild the raindrop with new important state
                let updated = Raindrop(
                    id: raindrop.id,
                    title: raindrop.title,
                    link: raindrop.link,
                    excerpt: raindrop.excerpt,
                    cover: raindrop.cover,
                    tags: raindrop.tags,
                    type: raindrop.type,
                    created: raindrop.created,
                    lastUpdate: raindrop.lastUpdate,
                    important: newState,
                    collection: raindrop.collection,
                    domain: raindrop.domain,
                    note: raindrop.note,
                    cache: raindrop.cache,
                    highlights: raindrop.highlights
                )
                raindrops[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed
    var displayedRaindrops: [Raindrop] {
        isSearching ? searchResults : raindrops
    }

    var hasMore: Bool {
        raindrops.count < totalCount
    }

    var rootCollections: [RaindropCollection] {
        collections.filter { $0.parent == nil }.sorted { $0.sort ?? 0 < $1.sort ?? 0 }
    }

    func children(for collection: RaindropCollection) -> [RaindropCollection] {
        collections.filter { $0.parent?.id == collection.id }.sorted { $0.sort ?? 0 < $1.sort ?? 0 }
    }
}
