// RaindropsListView.swift
// Middle column: search, filters, and multi-view bookmark browser

import SwiftUI

struct RaindropsListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var selectedRaindrop: Raindrop?

    var body: some View {
        VStack(spacing: 0) {
            headerChrome
            content
        }
        .navigationTitle(viewModel.navigationTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.totalCount > 0 {
                    Text("\(viewModel.totalCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }

                Menu {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Text(option.label)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("Sort")

                Menu {
                    ForEach(ViewMode.allCases) { mode in
                        Button {
                            viewModel.viewMode = mode
                        } label: {
                            Label(mode.label, systemImage: mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.viewMode.icon)
                }
                .help("View mode")

                Button {
                    Task { await viewModel.selectSystem(.stella) }
                } label: {
                    Image(systemName: "sparkles")
                }
                .help("Ask Stella")

                Button {
                    Task { await viewModel.sync() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .help("Sync (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isRefreshing || viewModel.isLoading)

                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add bookmark (⌘N)")
            }
        }
    }

    // MARK: - Search + filters (bookmarks only)
    private var headerChrome: some View {
        VStack(spacing: 8) {
            searchBar
            if viewModel.hasActiveFilters {
                filterBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13, weight: .medium))

            TextField("Search titles, tags, domains…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

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

                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.raindrops.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading bookmarks…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.displayedRaindrops.isEmpty {
            EmptyStateView(
                icon: viewModel.hasActiveFilters ? "magnifyingglass" : "bookmark.slash",
                title: viewModel.hasActiveFilters ? "No matches" : "No bookmarks yet",
                message: viewModel.hasActiveFilters
                    ? "Try adjusting filters or search terms."
                    : "Save your first link with ⌘N.",
                actionTitle: viewModel.hasActiveFilters ? "Clear filters" : "Add bookmark",
                action: {
                    if viewModel.hasActiveFilters {
                        viewModel.clearFilters()
                    } else {
                        viewModel.showAddSheet = true
                    }
                }
            )
        } else {
            switch viewModel.viewMode {
            case .list: listView
            case .headlines: headlinesView
            case .grid: gridView
            case .masonry: masonryView
            }
        }
    }

    // MARK: - Views
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    RaindropCardRow(raindrop: raindrop, style: .list, isSelected: selectedRaindrop?.id == raindrop.id)
                        .onTapGesture { selectedRaindrop = raindrop }
                        .contextMenu { raindropContextMenu(raindrop) }
                        .onAppear { maybeLoadMore(raindrop) }
                }
                loadMoreFooter
            }
            .padding(12)
        }
    }

    private var headlinesView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    RaindropCardRow(raindrop: raindrop, style: .headline, isSelected: selectedRaindrop?.id == raindrop.id)
                        .onTapGesture { selectedRaindrop = raindrop }
                        .contextMenu { raindropContextMenu(raindrop) }
                        .onAppear { maybeLoadMore(raindrop) }
                }
                loadMoreFooter
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)], spacing: 12) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    RaindropCardRow(raindrop: raindrop, style: .grid, isSelected: selectedRaindrop?.id == raindrop.id)
                        .onTapGesture { selectedRaindrop = raindrop }
                        .contextMenu { raindropContextMenu(raindrop) }
                        .onAppear { maybeLoadMore(raindrop) }
                }
            }
            .padding(12)
            loadMoreFooter
        }
    }

    private var masonryView: some View {
        ScrollView {
            MasonryLayout(columns: 2, spacing: 12) {
                ForEach(viewModel.displayedRaindrops) { raindrop in
                    RaindropCardRow(raindrop: raindrop, style: .masonry, isSelected: selectedRaindrop?.id == raindrop.id)
                        .onTapGesture { selectedRaindrop = raindrop }
                        .contextMenu { raindropContextMenu(raindrop) }
                        .onAppear { maybeLoadMore(raindrop) }
                }
            }
            .padding(12)
            loadMoreFooter
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.isLoading && !viewModel.raindrops.isEmpty {
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            }
            .padding(.vertical, 16)
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
        Button { viewModel.editingRaindrop = raindrop } label: {
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
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = h }
        }
    }

    private var listBody: some View {
        HStack(alignment: .top, spacing: 12) {
            typeBadge
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(raindrop.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    if raindrop.important == true {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 6) {
                    Text(raindrop.displayDomain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    let rel = Theme.relativeDate(raindrop.created)
                    if !rel.isEmpty {
                        Text("·").foregroundStyle(.quaternary)
                        Text(rel)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }

                if let tags = raindrop.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(6), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            if let cover = raindrop.cover, let url = URL(string: cover), !cover.isEmpty {
                coverImage(url: url, width: 64, height: 64)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(cardStroke)
        .shadow(color: .black.opacity(isHovering || isSelected ? 0.08 : 0.03), radius: isHovering ? 8 : 3, y: 2)
    }

    private var headlineBody: some View {
        HStack(spacing: 12) {
            typeBadge.scaleEffect(0.9)
            VStack(alignment: .leading, spacing: 2) {
                Text(raindrop.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(raindrop.displayDomain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if raindrop.important == true {
                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
            }
            Text(Theme.relativeDate(raindrop.created))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.12) : (isHovering ? Theme.subtleFill : .clear))
        )
    }

    private var gridBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let cover = raindrop.cover, let url = URL(string: cover), !cover.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: style == .masonry ? nil : 110)
                                .frame(minHeight: style == .masonry ? 80 : 110)
                                .clipped()
                        default:
                            coverPlaceholder
                        }
                    }
                } else {
                    coverPlaceholder
                }

                if raindrop.important == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(raindrop.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(style == .masonry ? 4 : 2)
                Text(raindrop.displayDomain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if style == .masonry, let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(4)
                }
            }
            .padding(10)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(cardStroke)
        .shadow(color: .black.opacity(isHovering || isSelected ? 0.1 : 0.04), radius: isHovering ? 10 : 4, y: 2)
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [raindrop.typeColor.opacity(0.2), raindrop.typeColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 110)
            .overlay {
                Image(systemName: raindrop.typeIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(raindrop.typeColor.opacity(0.5))
            }
    }

    private var typeBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(raindrop.typeColor.opacity(0.14))
                .frame(width: 30, height: 30)
            Image(systemName: raindrop.typeIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(raindrop.typeColor)
        }
    }

    private func coverImage(url: URL, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            case .empty:
                ProgressView().frame(width: width, height: height)
            default:
                EmptyView()
            }
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
