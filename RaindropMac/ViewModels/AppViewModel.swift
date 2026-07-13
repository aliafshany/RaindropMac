// AppViewModel.swift
// Central state management for the app

import Foundation
import Combine
import AppKit

@MainActor
class AppViewModel: ObservableObject {
    @Published var user: User?
    @Published var collections: [RaindropCollection] = []
    @Published var selectedCollectionId: Int = 0
    @Published var selectedCollection: RaindropCollection?
    @Published var raindrops: [Raindrop] = []
    @Published var tags: [RaindropTag] = []
    @Published var filters: FiltersResponse?
    @Published var stats: [StatItem] = []

    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var showAddSheet = false
    @Published var showNewCollectionSheet = false
    @Published var editingRaindrop: Raindrop?
    @Published var editingCollection: RaindropCollection?
    @Published var stellaContextRaindropId: Int? = nil
    @Published var totalCount = 0

    // View & filter state
    @Published var viewMode: ViewMode = {
        if let raw = UserDefaults.standard.string(forKey: "viewMode"),
           let mode = ViewMode(rawValue: raw) { return mode }
        return .list
    }() {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "viewMode") }
    }

    @Published var sortOption: SortOption = {
        if let raw = UserDefaults.standard.string(forKey: "sortOption"),
           let opt = SortOption(rawValue: raw) { return opt }
        return .newest
    }() {
        didSet {
            UserDefaults.standard.set(sortOption.rawValue, forKey: "sortOption")
            Task { await reloadCurrent() }
        }
    }

    @Published var selectedTag: String? = nil {
        didSet { Task { await reloadCurrent() } }
    }
    @Published var selectedType: String? = nil {
        didSet { Task { await reloadCurrent() } }
    }
    @Published var showImportantOnly = false {
        didSet { Task { await reloadCurrent() } }
    }
    @Published var showNoTagsOnly = false {
        didSet { Task { await reloadCurrent() } }
    }

    private var currentPage = 0
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init() {
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.reloadCurrent() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed

    var displayedRaindrops: [Raindrop] { raindrops }

    var hasMore: Bool { raindrops.count < totalCount }

    var rootCollections: [RaindropCollection] {
        collections.filter { $0.parent == nil }.sorted { ($0.sort ?? 0) < ($1.sort ?? 0) }
    }

    func children(for collection: RaindropCollection) -> [RaindropCollection] {
        collections.filter { $0.parent?.id == collection.id }.sorted { ($0.sort ?? 0) < ($1.sort ?? 0) }
    }

    var navigationTitle: String {
        if let tag = selectedTag { return "#\(tag)" }
        if selectedCollectionId == SystemCollection.favorites.rawValue { return "Favorites" }
        if let col = selectedCollection { return col.title }
        return SystemCollection(rawValue: selectedCollectionId)?.title ?? "All Bookmarks"
    }

    var allCount: Int { stats.first(where: { $0.id == 0 })?.count ?? totalCount }
    var unsortedCount: Int { stats.first(where: { $0.id == -1 })?.count ?? 0 }
    var trashCount: Int { stats.first(where: { $0.id == -99 })?.count ?? 0 }
    var favoritesCount: Int { filters?.important?.count ?? 0 }

    var hasActiveFilters: Bool {
        selectedTag != nil || selectedType != nil || showImportantOnly || showNoTagsOnly || !searchQuery.isEmpty
    }

    // MARK: - Search query composition
    private var composedSearch: String? {
        var parts: [String] = []
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { parts.append(q) }
        if let tag = selectedTag { parts.append("#\(tag)") }
        if let type = selectedType { parts.append("type:\(type)") }
        if showImportantOnly { parts.append("❤️") }
        if showNoTagsOnly { parts.append("notag:true") }
        if selectedCollectionId == SystemCollection.favorites.rawValue && !showImportantOnly {
            parts.append("❤️")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var activeApiCollectionId: Int {
        if selectedCollectionId == SystemCollection.favorites.rawValue { return 0 }
        if selectedCollectionId == SystemCollection.stella.rawValue { return 0 }
        return selectedCollectionId
    }

    // MARK: - Load Initial Data
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let userTask = APIService.shared.fetchUser()
            async let collectionsTask = APIService.shared.fetchCollections()
            async let statsTask = APIService.shared.fetchStats()
            let (fetchedUser, fetchedCollections, fetchedStats) = try await (userTask, collectionsTask, statsTask)
            user = fetchedUser
            collections = fetchedCollections.sorted { ($0.sort ?? 0) < ($1.sort ?? 0) }
            stats = fetchedStats
            await loadTagsAndFilters()
            await reloadCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadTagsAndFilters() async {
        do {
            async let tagsTask = APIService.shared.fetchTags(collectionId: activeApiCollectionId)
            async let filtersTask = APIService.shared.fetchFilters(collectionId: activeApiCollectionId)
            tags = try await tagsTask
            filters = try await filtersTask
        } catch {
            // non-fatal
        }
    }

    // MARK: - Navigation
    func selectSystem(_ system: SystemCollection) async {
        selectedCollectionId = system.rawValue
        selectedCollection = nil
        selectedTag = nil
        // Don't clear other filters for favorites since favorites IS a filter
        if system != .favorites {
            // keep type filters etc
        }
        await reloadCurrent()
        await loadTagsAndFilters()
    }

    func selectCollection(_ collection: RaindropCollection) async {
        selectedCollectionId = collection.id
        selectedCollection = collection
        selectedTag = nil
        await reloadCurrent()
        await loadTagsAndFilters()
    }

    func selectTag(_ tag: String?) async {
        selectedTag = tag
        // keep collection context
    }

    func clearFilters() {
        searchQuery = ""
        selectedTag = nil
        selectedType = nil
        showImportantOnly = false
        showNoTagsOnly = false
    }

    // MARK: - Reload
    func reloadCurrent() async {
        if selectedCollectionId == SystemCollection.stella.rawValue {
            raindrops = []
            totalCount = 0
            return
        }

        isLoading = raindrops.isEmpty
        currentPage = 0
        isSearching = composedSearch != nil

        do {
            let response = try await APIService.shared.fetchRaindrops(
                collectionId: activeApiCollectionId,
                page: 0,
                sort: sortOption.rawValue,
                search: composedSearch
            )
            raindrops = response.items
            totalCount = response.count
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        let nextPage = currentPage + 1
        isLoading = true
        do {
            let response = try await APIService.shared.fetchRaindrops(
                collectionId: activeApiCollectionId,
                page: nextPage,
                sort: sortOption.rawValue,
                search: composedSearch
            )
            raindrops.append(contentsOf: response.items)
            currentPage = nextPage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sync
    func sync() async {
        isRefreshing = true
        do {
            async let collectionsTask = APIService.shared.fetchCollections()
            async let statsTask = APIService.shared.fetchStats()
            async let tagsTask = APIService.shared.fetchTags(collectionId: activeApiCollectionId)
            async let filtersTask = APIService.shared.fetchFilters(collectionId: activeApiCollectionId)

            collections = try await collectionsTask
            stats = try await statsTask
            tags = try await tagsTask
            filters = try await filtersTask
            await reloadCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    // MARK: - Raindrop CRUD
    func addRaindrop(
        link: String,
        title: String?,
        tags: [String],
        collectionId: Int? = nil,
        note: String? = nil,
        important: Bool = false
    ) async {
        do {
            let colId = collectionId ?? selectedCollection?.id ?? -1
            let newRaindrop = try await APIService.shared.createRaindrop(
                link: link,
                title: title,
                collectionId: colId,
                tags: tags,
                note: note,
                important: important,
                pleaseParse: true
            )
            // Only insert if it matches current view
            if selectedCollectionId == colId || selectedCollectionId == 0 || selectedCollectionId == -1 {
                raindrops.insert(newRaindrop, at: 0)
                totalCount += 1
            }
            await loadTagsAndFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRaindrop(
        _ raindrop: Raindrop,
        link: String,
        title: String?,
        collectionId: Int,
        tags: [String],
        note: String? = nil,
        excerpt: String? = nil,
        important: Bool? = nil
    ) async {
        do {
            let updated = try await APIService.shared.updateRaindrop(
                id: raindrop.id,
                link: link,
                title: title,
                collectionId: collectionId,
                tags: tags,
                note: note,
                excerpt: excerpt,
                important: important
            )
            if let idx = raindrops.firstIndex(where: { $0.id == raindrop.id }) {
                // If moved out of current collection, remove
                if selectedCollectionId > 0 && collectionId != selectedCollectionId {
                    raindrops.remove(at: idx)
                    totalCount -= 1
                } else {
                    raindrops[idx] = updated
                }
            }
            await loadTagsAndFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRaindrop(_ raindrop: Raindrop) async {
        do {
            try await APIService.shared.deleteRaindrop(id: raindrop.id)
            raindrops.removeAll { $0.id == raindrop.id }
            totalCount = max(0, totalCount - 1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite(_ raindrop: Raindrop) async {
        let newState = !(raindrop.important ?? false)
        // Optimistic
        if let idx = raindrops.firstIndex(where: { $0.id == raindrop.id }) {
            raindrops[idx] = raindrop.with(important: newState)
        }
        do {
            let updated = try await APIService.shared.toggleFavorite(id: raindrop.id, important: newState)
            if let idx = raindrops.firstIndex(where: { $0.id == raindrop.id }) {
                raindrops[idx] = updated
            }
            // Remove from favorites view if unfavorited
            if selectedCollectionId == SystemCollection.favorites.rawValue && !newState {
                raindrops.removeAll { $0.id == raindrop.id }
                totalCount = max(0, totalCount - 1)
            }
        } catch {
            // Revert
            if let idx = raindrops.firstIndex(where: { $0.id == raindrop.id }) {
                raindrops[idx] = raindrop
            }
            errorMessage = error.localizedDescription
        }
    }

    func moveRaindrop(_ raindrop: Raindrop, to collectionId: Int) async {
        do {
            let updated = try await APIService.shared.moveRaindrop(id: raindrop.id, toCollectionId: collectionId)
            if selectedCollectionId > 0 && selectedCollectionId != collectionId {
                raindrops.removeAll { $0.id == raindrop.id }
                totalCount = max(0, totalCount - 1)
            } else if let idx = raindrops.firstIndex(where: { $0.id == raindrop.id }) {
                raindrops[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Collections CRUD
    func createCollection(title: String, parentId: Int? = nil) async {
        do {
            let col = try await APIService.shared.createCollection(title: title, parentId: parentId)
            collections.append(col)
            await selectCollection(col)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameCollection(_ collection: RaindropCollection, title: String) async {
        do {
            let updated = try await APIService.shared.updateCollection(id: collection.id, title: title)
            if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[idx] = updated
            }
            if selectedCollection?.id == collection.id {
                selectedCollection = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCollection(_ collection: RaindropCollection) async {
        do {
            try await APIService.shared.deleteCollection(id: collection.id)
            collections.removeAll { $0.id == collection.id || $0.parent?.id == collection.id }
            if selectedCollectionId == collection.id {
                await selectSystem(.all)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func emptyTrash() async {
        do {
            try await APIService.shared.emptyTrash()
            if selectedCollectionId == -99 {
                raindrops = []
                totalCount = 0
            }
            stats = try await APIService.shared.fetchStats()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers
    func openInBrowser(_ raindrop: Raindrop) {
        if let url = URL(string: raindrop.link) {
            NSWorkspace.shared.open(url)
        }
    }

    func copyLink(_ raindrop: Raindrop) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(raindrop.link, forType: .string)
    }

    func collectionTitle(for raindrop: Raindrop) -> String? {
        guard let id = raindrop.collection?.id else { return nil }
        if id == -1 { return "Unsorted" }
        return collections.first { $0.id == id }?.title
    }
}
