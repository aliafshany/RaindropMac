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

    // Selection / bulk
    @Published var isSelecting = false
    @Published var selectedIds: Set<Int> = []
    @Published var isBulkWorking = false

    // Sheets / tools
    @Published var showQuickSave = false
    @Published var showTagsManager = false
    @Published var showImportExport = false
    @Published var readerRaindrop: Raindrop?
    @Published var specialFilter: SpecialFilter?

    /// Close every floating panel so only one modal is open at a time.
    func closeAllModals() {
        showQuickSave = false
        showAddSheet = false
        showTagsManager = false
        showImportExport = false
        showNewCollectionSheet = false
        editingRaindrop = nil
        readerRaindrop = nil
    }

    func openQuickSave() {
        closeAllModals()
        showQuickSave = true
    }

    func openAddSheet() {
        closeAllModals()
        showAddSheet = true
    }

    func openTagsManager() {
        closeAllModals()
        showTagsManager = true
    }

    func openImportExport() {
        closeAllModals()
        showImportExport = true
    }

    func openReader(_ raindrop: Raindrop) {
        closeAllModals()
        readerRaindrop = raindrop
    }

    func openEditor(_ raindrop: Raindrop) {
        closeAllModals()
        editingRaindrop = raindrop
    }

    // View & filter state
    @Published var viewMode: ViewMode = {
        if let raw = UserDefaults.standard.string(forKey: "viewMode"),
           let mode = ViewMode(rawValue: raw) { return mode }
        // List shows cover thumbnails; better use of space than headlines
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
            guard oldValue != sortOption else { return }
            UserDefaults.standard.set(sortOption.rawValue, forKey: "sortOption")
            scheduleReload()
        }
    }

    @Published var selectedTag: String? = nil {
        didSet {
            guard oldValue != selectedTag else { return }
            scheduleReload()
        }
    }
    @Published var selectedType: String? = nil {
        didSet {
            guard oldValue != selectedType else { return }
            scheduleReload()
        }
    }
    @Published var showImportantOnly = false {
        didSet {
            guard oldValue != showImportantOnly else { return }
            scheduleReload()
        }
    }
    @Published var showNoTagsOnly = false {
        didSet {
            guard oldValue != showNoTagsOnly else { return }
            scheduleReload()
        }
    }

    private var currentPage = 0
    private var cancellables = Set<AnyCancellable>()
    private var reloadTask: Task<Void, Never>?
    /// Coalesce rapid filter/sort changes into one network call
    private var reloadGeneration = 0

    init() {
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleReload()
            }
            .store(in: &cancellables)
    }

    /// Debounce reloads so toggling filters quickly doesn't spam the API.
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            await reloadCurrent()
        }
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
        selectedTag != nil || selectedType != nil || showImportantOnly || showNoTagsOnly
            || !searchQuery.isEmpty || specialFilter != nil
    }

    var selectedRaindrops: [Raindrop] {
        raindrops.filter { selectedIds.contains($0.id) }
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
        if let specialFilter {
            parts.append(specialFilter.searchToken)
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
        specialFilter = nil
    }

    func applySpecialFilter(_ filter: SpecialFilter?) {
        specialFilter = filter
        Task { await reloadCurrent() }
    }

    // MARK: - Selection
    func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting { selectedIds.removeAll() }
    }

    func toggleSelection(_ id: Int) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func selectAllVisible() {
        selectedIds = Set(raindrops.map(\.id))
    }

    func clearSelection() {
        selectedIds.removeAll()
    }

    // MARK: - Bulk actions
    func bulkMove(to collectionId: Int) async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        isBulkWorking = true
        do {
            try await APIService.shared.bulkUpdateRaindrops(ids: ids, collectionId: collectionId)
            if selectedCollectionId > 0 && selectedCollectionId != collectionId {
                raindrops.removeAll { selectedIds.contains($0.id) }
                totalCount = max(0, totalCount - ids.count)
            }
            clearSelection()
            isSelecting = false
            await reloadCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBulkWorking = false
    }

    func bulkSetFavorite(_ important: Bool) async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        isBulkWorking = true
        do {
            try await APIService.shared.bulkUpdateRaindrops(ids: ids, important: important)
            for i in raindrops.indices where selectedIds.contains(raindrops[i].id) {
                raindrops[i] = raindrops[i].with(important: important)
            }
            if selectedCollectionId == SystemCollection.favorites.rawValue && !important {
                raindrops.removeAll { selectedIds.contains($0.id) }
            }
            clearSelection()
            isSelecting = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isBulkWorking = false
    }

    func bulkAddTags(_ tags: [String]) async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty, !tags.isEmpty else { return }
        isBulkWorking = true
        do {
            // Raindrop bulk tags typically replace; merge per-item for safety
            for id in ids {
                if let item = raindrops.first(where: { $0.id == id }) {
                    let merged = Array(Set((item.tags ?? []) + tags)).sorted()
                    let updated = try await APIService.shared.updateRaindrop(id: id, tags: merged)
                    if let idx = raindrops.firstIndex(where: { $0.id == id }) {
                        raindrops[idx] = updated
                    }
                } else {
                    try await APIService.shared.updateRaindrop(id: id, tags: tags)
                }
            }
            await loadTagsAndFilters()
            clearSelection()
            isSelecting = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isBulkWorking = false
    }

    func bulkDelete() async {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        isBulkWorking = true
        do {
            try await APIService.shared.bulkDeleteRaindrops(ids: ids)
            raindrops.removeAll { selectedIds.contains($0.id) }
            totalCount = max(0, totalCount - ids.count)
            clearSelection()
            isSelecting = false
        } catch {
            // Fallback: delete one by one
            for id in ids {
                try? await APIService.shared.deleteRaindrop(id: id)
            }
            raindrops.removeAll { ids.contains($0.id) }
            clearSelection()
            isSelecting = false
        }
        isBulkWorking = false
    }

    // MARK: - Tags management
    func renameTag(from old: String, to new: String) async {
        do {
            try await APIService.shared.renameTag(old: old, new: new)
            if selectedTag == old { selectedTag = new }
            await loadTagsAndFilters()
            await reloadCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTag(_ tag: String) async {
        do {
            try await APIService.shared.deleteTags([tag])
            if selectedTag == tag { selectedTag = nil }
            await loadTagsAndFilters()
            await reloadCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Collection settings
    func updateCollectionSettings(_ collection: RaindropCollection, title: String, isPublic: Bool) async {
        do {
            let updated = try await APIService.shared.updateCollection(
                id: collection.id,
                title: title,
                isPublic: isPublic
            )
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

    // MARK: - Export / Import
    func exportLibraryCSV() async -> URL? {
        do {
            let items = try await APIService.shared.fetchAllRaindrops(collectionId: 0)
            var csv = "id,title,link,domain,tags,important,created,note\n"
            for r in items {
                let tags = (r.tags ?? []).joined(separator: "|")
                let title = r.title.replacingOccurrences(of: "\"", with: "\"\"")
                let note = (r.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\(r.id),\"\(title)\",\"\(r.link)\",\"\(r.displayDomain)\",\"\(tags)\",\(r.important == true),\"\(r.created ?? "")\",\"\(note)\"\n"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("raindrop-export.csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func exportLibraryHTML() async -> URL? {
        do {
            let items = try await APIService.shared.fetchAllRaindrops(collectionId: 0)
            var html = """
            <!DOCTYPE NETSCAPE-Bookmark-file-1>
            <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
            <TITLE>Raindrop Export</TITLE>
            <H1>Raindrop Export</H1>
            <DL><p>
            """
            for r in items {
                let title = r.displayTitle
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                html += "<DT><A HREF=\"\(r.link)\">\(title)</A>\n"
            }
            html += "</DL><p>\n"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("raindrop-export.html")
            try html.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importBookmarks(from url: URL) async -> Int {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            errorMessage = "Could not read file."
            return 0
        }
        var links: [(url: String, title: String?)] = []

        // HTML bookmarks: HREF="..."
        let hrefPattern = #"<A[^>]+HREF="([^"]+)"[^>]*>([^<]*)</A>"#
        if let regex = try? NSRegularExpression(pattern: hrefPattern, options: .caseInsensitive) {
            let range = NSRange(data.startIndex..., in: data)
            regex.enumerateMatches(in: data, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 3,
                      let urlR = Range(match.range(at: 1), in: data),
                      let titleR = Range(match.range(at: 2), in: data) else { return }
                let link = String(data[urlR])
                let title = String(data[titleR])
                if link.hasPrefix("http") {
                    links.append((link, title.isEmpty ? nil : title))
                }
            }
        }

        // Plain text / CSV: one URL per line
        if links.isEmpty {
            for line in data.components(separatedBy: .newlines) {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("http://") || t.hasPrefix("https://") {
                    links.append((t, nil))
                }
            }
        }

        var imported = 0
        let colId = selectedCollection?.id ?? -1
        for item in links.prefix(200) { // safety cap
            do {
                _ = try await APIService.shared.createRaindrop(
                    link: item.url,
                    title: item.title,
                    collectionId: colId,
                    pleaseParse: true
                )
                imported += 1
            } catch {
                continue
            }
        }
        if imported > 0 {
            await reloadCurrent()
            await loadTagsAndFilters()
        }
        return imported
    }

    // MARK: - Reload
    func reloadCurrent() async {
        if selectedCollectionId == SystemCollection.stella.rawValue {
            raindrops = []
            totalCount = 0
            return
        }

        reloadGeneration &+= 1
        let gen = reloadGeneration

        isLoading = raindrops.isEmpty
        currentPage = 0
        isSearching = composedSearch != nil

        let col = activeApiCollectionId
        let sort = sortOption.rawValue
        let search = composedSearch

        do {
            let response = try await APIService.shared.fetchRaindrops(
                collectionId: col,
                page: 0,
                sort: sort,
                search: search
            )
            // Drop stale responses if user navigated again
            guard gen == reloadGeneration else { return }
            raindrops = response.items
            totalCount = response.count
        } catch is CancellationError {
            return
        } catch {
            guard gen == reloadGeneration else { return }
            errorMessage = error.localizedDescription
        }
        if gen == reloadGeneration {
            isLoading = false
        }
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
