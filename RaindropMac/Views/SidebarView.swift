// SidebarView.swift
// Modern collections sidebar

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService

    @AppStorage("isCollectionsExpanded") private var isCollectionsExpanded = true
    @AppStorage("isTagsExpanded") private var isTagsExpanded = true
    @AppStorage("isFiltersExpanded") private var isFiltersExpanded = true

    @State private var newCollectionName = ""
    @State private var showNewCollection = false
    @State private var renameTarget: RaindropCollection?
    @State private var renameText = ""
    @State private var deleteTarget: RaindropCollection?

    var body: some View {
        List {
            userSection
            systemSection
            filtersSection
            collectionsSection
            tagsSection
            stellaSection
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .navigationTitle("Raindrop")
        .alert("New Collection", isPresented: $showNewCollection) {
            TextField("Name", text: $newCollectionName)
            Button("Cancel", role: .cancel) { newCollectionName = "" }
            Button("Create") {
                let name = newCollectionName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task {
                    await viewModel.createCollection(title: name)
                    newCollectionName = ""
                }
            }
        } message: {
            Text("Create a new root collection.")
        }
        .alert("Rename Collection", isPresented: renamePresented) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                if let col = renameTarget {
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    Task { await viewModel.renameCollection(col, title: name) }
                }
                renameTarget = nil
            }
        }
        .alert("Delete Collection?", isPresented: deletePresented) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let col = deleteTarget {
                    Task { await viewModel.deleteCollection(col) }
                }
                deleteTarget = nil
            }
        } message: {
            Text("Bookmarks will move to Trash. Nested collections are also removed.")
        }
    }

    private var renamePresented: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    // MARK: - Sections

    @ViewBuilder
    private var userSection: some View {
        if let user = viewModel.user {
            UserHeaderView(user: user)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                .listRowSeparator(.hidden)
        }
    }

    private var systemSection: some View {
        Section {
            systemRow(.all, count: viewModel.allCount)
            systemRow(.favorites, count: viewModel.favoritesCount)
            systemRow(.unsorted, count: viewModel.unsortedCount)
            systemRow(.trash, count: viewModel.trashCount)
        }
    }

    @ViewBuilder
    private var filtersSection: some View {
        if viewModel.filters != nil {
            Section {
                DisclosureGroup(isExpanded: $isFiltersExpanded) {
                    FiltersListContent(viewModel: viewModel)
                } label: {
                    sectionLabel("Filters")
                }
            }
        }
    }

    private var collectionsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isCollectionsExpanded) {
                if viewModel.rootCollections.isEmpty {
                    Text("No collections yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.rootCollections) { collection in
                        CollectionRow(
                            collection: collection,
                            depth: 0,
                            onSelect: { col in Task { await viewModel.selectCollection(col) } },
                            onRename: { col in
                                renameTarget = col
                                renameText = col.title
                            },
                            onDelete: { col in deleteTarget = col },
                            onNewChild: { parent in
                                Task { await viewModel.createCollection(title: "New collection", parentId: parent.id) }
                            }
                        )
                    }
                }

                Button {
                    showNewCollection = true
                } label: {
                    Label("New Collection", systemImage: "folder.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            } label: {
                sectionLabel("Collections")
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !viewModel.tags.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $isTagsExpanded) {
                    ForEach(Array(viewModel.tags.prefix(40))) { tag in
                        tagRow(tag)
                    }
                } label: {
                    sectionLabel("Tags")
                }
            }
        }
    }

    private var stellaSection: some View {
        Section {
            systemRow(.stella, count: 0)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Add bookmark (⌘N)")

            Menu {
                Button {
                    showNewCollection = true
                } label: {
                    Label("New Collection", systemImage: "folder.badge.plus")
                }
                Divider()
                Button(role: .destructive) {
                    authService.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(Theme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Rows

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func systemRow(_ system: SystemCollection, count: Int) -> some View {
        let selected = viewModel.selectedCollectionId == system.rawValue && viewModel.selectedTag == nil
        return SidebarRow(
            icon: system.icon,
            iconColor: system.color,
            title: system.title,
            count: count,
            isSelected: selected
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if system != .stella {
                viewModel.stellaContextRaindropId = nil
            }
            Task { await viewModel.selectSystem(system) }
        }
        .contextMenu {
            if system == .trash && count > 0 {
                Button("Empty Trash", role: .destructive) {
                    Task { await viewModel.emptyTrash() }
                }
            }
        }
    }

    private func tagRow(_ tag: RaindropTag) -> some View {
        let selected = viewModel.selectedTag == tag.tag
        return SidebarRow(
            icon: "number",
            iconColor: selected ? Theme.accent : .secondary,
            title: tag.tag,
            count: tag.count,
            isSelected: selected
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                if selected {
                    await viewModel.selectTag(nil)
                } else {
                    await viewModel.selectTag(tag.tag)
                }
            }
        }
        .contextMenu {
            Button("Filter by #\(tag.tag)") {
                Task { await viewModel.selectTag(tag.tag) }
            }
            Button("Clear tag filter", role: .destructive) {
                Task { await viewModel.selectTag(nil) }
            }
        }
    }
}

// MARK: - Filters content (split for type-checker)
private struct FiltersListContent: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if let types = viewModel.filters?.types {
                ForEach(types) { type in
                    typeRow(type)
                }
            }
            noTagsRow
            brokenRow
            duplicatesRow
        }
    }

    private func typeRow(_ type: TypeFilter) -> some View {
        let selected = viewModel.selectedType == type.type
        return SidebarRow(
            icon: type.icon,
            iconColor: selected ? Theme.accent : .secondary,
            title: type.label,
            count: type.count,
            isSelected: selected
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if selected {
                viewModel.selectedType = nil
            } else {
                viewModel.selectedType = type.type
                viewModel.showNoTagsOnly = false
            }
        }
    }

    @ViewBuilder
    private var noTagsRow: some View {
        if let noTag = viewModel.filters?.notag?.count, noTag > 0 {
            SidebarRow(
                icon: "tag.slash",
                iconColor: .gray,
                title: "No tags",
                count: noTag,
                isSelected: viewModel.showNoTagsOnly
            )
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.showNoTagsOnly.toggle()
                if viewModel.showNoTagsOnly { viewModel.selectedType = nil }
            }
        }
    }

    @ViewBuilder
    private var brokenRow: some View {
        if let broken = viewModel.filters?.broken?.count, broken > 0 {
            SidebarRow(icon: "link.badge.plus", iconColor: .red, title: "Broken", count: broken, isSelected: false)
                .opacity(0.7)
        }
    }

    @ViewBuilder
    private var duplicatesRow: some View {
        if let dupes = viewModel.filters?.duplicates?.count, dupes > 0 {
            SidebarRow(icon: "doc.on.doc", iconColor: .orange, title: "Duplicates", count: dupes, isSelected: false)
                .opacity(0.7)
        }
    }
}

// MARK: - User header
struct UserHeaderView: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                userSubtitle
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.subtleFill)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatar = user.avatar, let url = URL(string: avatar) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    avatarFallback
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    @ViewBuilder
    private var userSubtitle: some View {
        if user.pro {
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                Text("Pro")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow)
            }
        } else {
            Text(user.email)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            Text(String(user.name.prefix(1)).uppercased())
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Collection row (nested)
struct CollectionRow: View {
    @EnvironmentObject var viewModel: AppViewModel
    let collection: RaindropCollection
    let depth: Int
    let onSelect: (RaindropCollection) -> Void
    let onRename: (RaindropCollection) -> Void
    let onDelete: (RaindropCollection) -> Void
    let onNewChild: (RaindropCollection) -> Void

    @State private var expanded = true

    var body: some View {
        let kids = viewModel.children(for: collection)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                expandButton(hasChildren: !kids.isEmpty)

                SidebarRow(
                    icon: "folder.fill",
                    iconColor: collection.displayColor,
                    title: collection.title,
                    count: collection.count,
                    isSelected: viewModel.selectedCollectionId == collection.id && viewModel.selectedTag == nil
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect(collection) }
            .contextMenu { collectionMenu }
            .padding(.leading, CGFloat(depth) * 12)

            if expanded {
                ForEach(kids) { child in
                    CollectionRow(
                        collection: child,
                        depth: depth + 1,
                        onSelect: onSelect,
                        onRename: onRename,
                        onDelete: onDelete,
                        onNewChild: onNewChild
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func expandButton(hasChildren: Bool) -> some View {
        if hasChildren {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 14)
        }
    }

    @ViewBuilder
    private var collectionMenu: some View {
        Button { onSelect(collection) } label: { Label("Open", systemImage: "folder") }
        Button { onRename(collection) } label: { Label("Rename", systemImage: "pencil") }
        Button { onNewChild(collection) } label: { Label("New Subcollection", systemImage: "folder.badge.plus") }
        Divider()
        Button(role: .destructive) { onDelete(collection) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Row
struct SidebarRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(isSelected ? 0.22 : 0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .foregroundStyle(Color.primary.opacity(isSelected ? 1.0 : 0.9))

            Spacer(minLength: 4)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
        )
    }
}
