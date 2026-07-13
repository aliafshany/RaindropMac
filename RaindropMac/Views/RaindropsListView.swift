// RaindropsListView.swift
// Bookmark browser — one clean search bar in content (not stacked in toolbar chrome)

import SwiftUI

struct RaindropsListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var selectedRaindrop: Raindrop?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Compact search — not full-width
            HStack {
                searchBar
                    .frame(maxWidth: 280)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if viewModel.hasActiveFilters {
                filterBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
            if viewModel.isSelecting {
                bulkBar
            }
            Divider().opacity(0.35)
            content
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationSubtitle(viewModel.totalCount > 0 ? "\(viewModel.totalCount) items" : "")
    }

    /// Compact single-surface search (left-aligned, max ~280pt).
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .tooltip("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.searchFieldFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    searchFocused ? Theme.accent.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
        .accessibilityLabel("Search bookmarks")
    }

    private var bulkBar: some View {
        HStack(spacing: 10) {
            Text("\(viewModel.selectedIds.count) selected")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Button("All") { viewModel.selectAllVisible() }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))

            Button("None") { viewModel.clearSelection() }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            if viewModel.isBulkWorking {
                ProgressView().controlSize(.small)
            }

            Menu("Move") {
                Button("Unsorted") {
                    Task { await viewModel.bulkMove(to: -1) }
                }
                Divider()
                ForEach(viewModel.rootCollections) { col in
                    Button(col.title) {
                        Task { await viewModel.bulkMove(to: col.id) }
                    }
                    ForEach(viewModel.children(for: col)) { child in
                        Button("  \(child.title)") {
                            Task { await viewModel.bulkMove(to: child.id) }
                        }
                    }
                }
            }
            .disabled(viewModel.selectedIds.isEmpty || viewModel.isBulkWorking)

            Button {
                Task { await viewModel.bulkSetFavorite(true) }
            } label: {
                Image(systemName: "star.fill")
            }
            .tooltip("Favorite selected")
            .disabled(viewModel.selectedIds.isEmpty || viewModel.isBulkWorking)

            Button {
                Task { await viewModel.bulkSetFavorite(false) }
            } label: {
                Image(systemName: "star.slash")
            }
            .tooltip("Unfavorite selected")
            .disabled(viewModel.selectedIds.isEmpty || viewModel.isBulkWorking)

            Button(role: .destructive) {
                Task { await viewModel.bulkDelete() }
            } label: {
                Image(systemName: "trash")
            }
            .tooltip("Move selected to trash")
            .disabled(viewModel.selectedIds.isEmpty || viewModel.isBulkWorking)

            Button("Done") {
                viewModel.toggleSelecting()
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.subtleFill)
    }

    // MARK: - Filters only (search is in MainAppView toolbar)
    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let tag = viewModel.selectedTag {
                    ModernChip(title: "#\(tag)", icon: "number", color: Theme.accent, isSelected: true) {
                        Task { await viewModel.selectTag(nil) }
                    }
                }
                if let type = viewModel.selectedType {
                    ModernChip(title: type.capitalized, icon: "doc", color: .blue, isSelected: true) {
                        viewModel.selectedType = nil
                    }
                }
                if viewModel.showImportantOnly || viewModel.selectedCollectionId == SystemCollection.favorites.rawValue {
                    ModernChip(title: "Favorites", icon: "star.fill", color: .yellow, isSelected: true) {
                        if viewModel.selectedCollectionId == SystemCollection.favorites.rawValue {
                            Task { await viewModel.selectSystem(.all) }
                        } else {
                            viewModel.showImportantOnly = false
                        }
                    }
                }
                if viewModel.showNoTagsOnly {
                    ModernChip(title: "No tags", icon: "tag.slash", color: .gray, isSelected: true) {
                        viewModel.showNoTagsOnly = false
                    }
                }
                if !viewModel.searchQuery.isEmpty {
                    ModernChip(title: "“\(viewModel.searchQuery)”", icon: "magnifyingglass", color: .secondary, isSelected: true) {
                        viewModel.searchQuery = ""
                    }
                }
                if let special = viewModel.specialFilter {
                    ModernChip(title: special.title, icon: special.icon, color: .orange, isSelected: true) {
                        viewModel.applySpecialFilter(nil)
                    }
                }

                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.raindrops.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.displayedRaindrops.isEmpty {
            EmptyStateView(
                icon: viewModel.hasActiveFilters ? "magnifyingglass" : "bookmark.slash",
                title: viewModel.hasActiveFilters ? "No matches" : "No bookmarks yet",
                message: viewModel.hasActiveFilters
                    ? "Try adjusting filters or search."
                    : "Save your first link with ⌘N.",
                actionTitle: viewModel.hasActiveFilters ? "Clear filters" : "Add bookmark",
                action: {
                    if viewModel.hasActiveFilters {
                        viewModel.clearFilters()
                    } else {
                        viewModel.openAddSheet()
                    }
                }
            )
        } else {
            // Identity by mode without list-wide spring animation (cheaper)
            Group {
                switch viewModel.viewMode {
                case .list: listView
                case .headlines: headlinesView
                case .grid: gridView
                case .masonry: masonryView
                }
            }
            .id(viewModel.viewMode)
        }
    }

    /// Extra trailing inset so the overlay scrollbar doesn’t cover cards (esp. grid).
    private var scrollContentInsets: EdgeInsets {
        EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 18)
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    row(raindrop, style: .list)
                }
                loadMoreFooter
            }
            .padding(scrollContentInsets)
        }
        .scrollIndicators(.automatic)
        .safeAreaPadding(.trailing, 2)
    }

    private var headlinesView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    row(raindrop, style: .headline)
                }
                loadMoreFooter
            }
            .padding(.vertical, 6)
            .padding(.leading, 8)
            .padding(.trailing, 16)
        }
        .scrollIndicators(.automatic)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    // Flexible cells with equal width — prevents title overflow into next card
                    GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12, alignment: .top)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    row(raindrop, style: .grid)
                }
            }
            .padding(.top, 10)
            .padding(.leading, 12)
            .padding(.bottom, 10)
            .padding(.trailing, 20)
            loadMoreFooter
                .padding(.trailing, 20)
        }
        .scrollIndicators(.automatic)
    }

    private var masonryView: some View {
        ScrollView {
            MasonryLayout(columns: 2, spacing: 10) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    row(raindrop, style: .masonry)
                }
            }
            .padding(.top, 10)
            .padding(.leading, 10)
            .padding(.bottom, 10)
            .padding(.trailing, 20)
            loadMoreFooter
                .padding(.trailing, 20)
        }
        .scrollIndicators(.automatic)
    }

    @ViewBuilder
    private func row(_ raindrop: Raindrop, style: RaindropCardStyle) -> some View {
        let isChecked = viewModel.selectedIds.contains(raindrop.id)
        let isGrid = style == .grid || style == .masonry

        HStack(alignment: .top, spacing: 6) {
            if viewModel.isSelecting {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? Theme.accent : .secondary)
                    .font(.system(size: 14))
                    .padding(.top, isGrid ? 6 : 0)
                    .onTapGesture { viewModel.toggleSelection(raindrop.id) }
            }
            RaindropCardRow(
                raindrop: raindrop,
                style: style,
                isSelected: selectedRaindrop?.id == raindrop.id || isChecked
            )
            // Critical for grid: cell must own its width so titles can't spill
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onTapGesture {
                if viewModel.isSelecting {
                    viewModel.toggleSelection(raindrop.id)
                } else {
                    selectedRaindrop = raindrop
                }
            }
            .contextMenu { raindropContextMenu(raindrop) }
            .onAppear { maybeLoadMore(raindrop) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.isLoading && !viewModel.raindrops.isEmpty {
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            }
            .padding(.vertical, 14)
        }
    }

    private func maybeLoadMore(_ raindrop: Raindrop) {
        if raindrop.id == viewModel.displayedRaindrops.last?.id && viewModel.hasMore {
            Task { await viewModel.loadNextPage() }
        }
    }

    @ViewBuilder
    private func raindropContextMenu(_ raindrop: Raindrop) -> some View {
        Button { viewModel.openInBrowser(raindrop) } label: {
            Label("Open in Browser", systemImage: "safari")
        }
        Button { viewModel.openReader(raindrop) } label: {
            Label("Open Reader", systemImage: "doc.text.magnifyingglass")
        }
        Button { viewModel.copyLink(raindrop) } label: {
            Label("Copy Link", systemImage: "link")
        }
        Button {
            Task { await viewModel.toggleFavorite(raindrop) }
        } label: {
            Label(
                raindrop.important == true ? "Remove Favorite" : "Add to Favorites",
                systemImage: raindrop.important == true ? "star.slash" : "star"
            )
        }
        Button {
            viewModel.stellaContextRaindropId = raindrop.id
            Task { await viewModel.selectSystem(.stella) }
        } label: {
            Label("Ask Stella", systemImage: "sparkles")
        }
        Button { viewModel.openEditor(raindrop) } label: {
            Label("Edit", systemImage: "pencil")
        }

        if !viewModel.collections.isEmpty {
            Menu("Move to…") {
                Button("Unsorted") {
                    Task { await viewModel.moveRaindrop(raindrop, to: -1) }
                }
                Divider()
                ForEach(viewModel.rootCollections) { col in
                    Button(col.title) {
                        Task { await viewModel.moveRaindrop(raindrop, to: col.id) }
                    }
                    ForEach(viewModel.children(for: col)) { child in
                        Button("  \(child.title)") {
                            Task { await viewModel.moveRaindrop(raindrop, to: child.id) }
                        }
                    }
                }
            }
        }

        Divider()
        Button(role: .destructive) {
            Task { await viewModel.deleteRaindrop(raindrop) }
            if selectedRaindrop?.id == raindrop.id { selectedRaindrop = nil }
        } label: {
            Label(viewModel.selectedCollectionId == -99 ? "Delete Forever" : "Move to Trash", systemImage: "trash")
        }
    }
}

// MARK: - Card styles
enum RaindropCardStyle {
    case list, headline, grid, masonry
}

struct RaindropCardRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let raindrop: Raindrop
    let style: RaindropCardStyle
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        Group {
            switch style {
            case .list: listBody
            case .headline: headlineBody
            case .grid, .masonry: gridBody
            }
        }
        // Lightweight hover: only color/stroke, no scale (scale re-rasters every row)
        .onHover { isHovering = $0 }
    }

    private var listBody: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail(size: Theme.thumbSize)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(raindrop.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    if raindrop.important == true {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                            .fixedSize()
                    }
                }

                HStack(spacing: 5) {
                    Text(raindrop.displayDomain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    let rel = Theme.relativeDate(raindrop.created)
                    if !rel.isEmpty {
                        Text("·").foregroundStyle(.quaternary).font(.system(size: 11))
                        Text(rel)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                    }
                }

                if let tags = raindrop.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(5), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(cardStroke)
        // Static soft shadow — animated elevation per-row is costly while scrolling
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var headlineBody: some View {
        HStack(spacing: 10) {
            thumbnail(size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(raindrop.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(raindrop.displayDomain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if raindrop.important == true {
                Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
            }
            Text(Theme.relativeDate(raindrop.created))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.12) : (isHovering ? Theme.subtleFill : .clear))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var gridBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = raindrop.coverURL {
                        AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                coverPlaceholder(height: 96)
                            }
                        }
                    } else {
                        coverPlaceholder(height: 96)
                    }
                }
                // Fixed cover height so cards align; clip overflow
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .clipped()

                if raindrop.important == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                        .padding(5)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            // Fixed text block height so neighboring titles never collide
            VStack(alignment: .leading, spacing: 3) {
                Text(raindrop.displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    // minWidth 0 is required for truncation inside flexible grid cells
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(raindrop.displayDomain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if style == .masonry, let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            // Reserve consistent title area (2 lines + domain)
            .frame(minHeight: style == .masonry ? 56 : 44, alignment: .topLeading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(cardStroke)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .clipped()
    }

    private func thumbnail(size: CGFloat) -> some View {
        Group {
            if let url = raindrop.coverURL {
                // Transaction disables AsyncImage fade — less main-thread work while scrolling
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty:
                        thumbBackdrop
                    default:
                        thumbBackdrop.overlay {
                            Image(systemName: raindrop.typeIcon)
                                .font(.system(size: size * 0.32, weight: .medium))
                                .foregroundStyle(raindrop.typeColor.opacity(0.55))
                        }
                    }
                }
            } else {
                thumbBackdrop.overlay {
                    Image(systemName: raindrop.typeIcon)
                        .font(.system(size: size * 0.32, weight: .medium))
                        .foregroundStyle(raindrop.typeColor.opacity(0.55))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .drawingGroup() // flatten thumbnail into one layer
    }

    private var thumbBackdrop: some View {
        LinearGradient(
            colors: [raindrop.typeColor.opacity(0.22), raindrop.typeColor.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func coverPlaceholder(height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [raindrop.typeColor.opacity(0.2), raindrop.typeColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: height)
            .overlay {
                Image(systemName: raindrop.typeIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(raindrop.typeColor.opacity(0.5))
            }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(isSelected ? Theme.accent.opacity(0.1) : Theme.cardBackground.opacity(isHovering ? 1 : 0.85))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .stroke(isSelected ? Theme.accent.opacity(0.45) : Color.primary.opacity(isHovering ? 0.1 : 0.06), lineWidth: 1)
    }
}
