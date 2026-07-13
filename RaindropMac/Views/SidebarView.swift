// SidebarView.swift
// Folders flush-left like system rows — hierarchy via "Parent › Child", zero indent

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService

    @AppStorage("isTagsExpanded") private var isTagsExpanded = false

    @State private var newCollectionName = ""
    @State private var showNewCollection = false
    @State private var renameTarget: RaindropCollection?
    @State private var renameText = ""
    @State private var deleteTarget: RaindropCollection?

    /// Shared leading inset — system rows and folders must match exactly
    private let edge = EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)

    var body: some View {
        List {
            Section {
                systemRow(.all, count: viewModel.allCount)
                systemRow(.favorites, count: viewModel.favoritesCount)
                systemRow(.unsorted, count: viewModel.unsortedCount)
                systemRow(.trash, count: viewModel.trashCount)
                systemRow(.stella, count: 0)
            }

            Section("Folders") {
                if flatFolders.isEmpty {
                    Text("No folders yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .listRowInsets(edge)
                } else {
                    ForEach(flatFolders) { item in
                        folderRow(item)
                    }
                }

                Button {
                    showNewCollection = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 16)
                        Text("New Folder")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .listRowInsets(edge)
            }

            if !viewModel.tags.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $isTagsExpanded) {
                        ForEach(Array(viewModel.tags.prefix(30))) { tag in
                            tagRow(tag)
                        }
                        Button {
                            viewModel.openTagsManager()
                        } label: {
                            Label("Manage tags…", systemImage: "slider.horizontal.3")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(edge)
                    } label: {
                        Text("Tags")
                    }
                }
            }

            Section("Tools") {
                if let broken = viewModel.filters?.broken?.count, broken > 0 {
                    Button {
                        viewModel.applySpecialFilter(.broken)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link.badge.plus")
                                .foregroundStyle(.red)
                                .frame(width: 16)
                            Text("Broken")
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(broken)")
                                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(edge)
                }
                if let dupes = viewModel.filters?.duplicates?.count, dupes > 0 {
                    Button {
                        viewModel.applySpecialFilter(.duplicates)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.orange)
                                .frame(width: 16)
                            Text("Duplicates")
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(dupes)")
                                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(edge)
                }
                Button {
                    viewModel.openImportExport()
                } label: {
                    Label("Import / Export", systemImage: "square.and.arrow.up.on.square")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .listRowInsets(edge)
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 26)
        .navigationTitle("Library")
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert("New Folder", isPresented: $showNewCollection) {
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
        }
        .alert("Rename Folder", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
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
        .alert("Delete Folder?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let col = deleteTarget {
                    Task { await viewModel.deleteCollection(col) }
                }
                deleteTarget = nil
            }
        } message: {
            Text("Bookmarks move to Trash. Nested folders are also removed.")
        }
    }

    // MARK: - Flat folder list (no tree indent → full width for names)

    private struct FlatFolder: Identifiable {
        let id: Int
        let collection: RaindropCollection
        /// Shown label, e.g. "Trade › Orderflow" for nested
        let label: String
    }

    private var flatFolders: [FlatFolder] {
        var result: [FlatFolder] = []

        func walk(_ collection: RaindropCollection, path: [String]) {
            let nextPath = path + [collection.title]
            let label: String
            if path.isEmpty {
                label = collection.title
            } else {
                // Keep parent short so child name stays readable
                label = path.joined(separator: " › ") + " › " + collection.title
            }
            result.append(FlatFolder(id: collection.id, collection: collection, label: label))
            for child in viewModel.children(for: collection) {
                walk(child, path: nextPath)
            }
        }

        for root in viewModel.rootCollections {
            walk(root, path: [])
        }
        return result
    }

    private func folderRow(_ item: FlatFolder) -> some View {
        let col = item.collection
        let selected = viewModel.selectedCollectionId == col.id && viewModel.selectedTag == nil

        return Button {
            Task { await viewModel.selectCollection(col) }
        } label: {
            // Exact same layout metrics as systemRow — flush left
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(col.displayColor)
                    .frame(width: 16, alignment: .center)

                Text(item.label)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle) // keep start + end of long nested paths
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(item.label)

                if col.count > 0 {
                    Text("\(col.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            selected
                ? Theme.accent.opacity(0.12)
                : Color.clear
        )
        .listRowInsets(edge)
        .contextMenu {
            Button {
                Task { await viewModel.selectCollection(col) }
            } label: {
                Label("Open", systemImage: "folder")
            }
            Button {
                renameTarget = col
                renameText = col.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                Task {
                    await viewModel.createCollection(title: "New collection", parentId: col.id)
                }
            } label: {
                Label("New Subfolder", systemImage: "folder.badge.plus")
            }
            Divider()
            Button(role: .destructive) {
                deleteTarget = col
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - System / tags (same insets + icon width as folders)

    private func systemRow(_ system: SystemCollection, count: Int) -> some View {
        let selected = viewModel.selectedCollectionId == system.rawValue && viewModel.selectedTag == nil
        return Button {
            if system != .stella {
                viewModel.stellaContextRaindropId = nil
            }
            Task { await viewModel.selectSystem(system) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: system.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accent : system.color)
                    .frame(width: 16, alignment: .center)

                Text(system.shortTitle)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? Theme.accent.opacity(0.12) : Color.clear)
        .listRowInsets(edge)
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
        return Button {
            Task {
                if selected {
                    await viewModel.selectTag(nil)
                } else {
                    await viewModel.selectTag(tag.tag)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                    .frame(width: 16, alignment: .center)

                Text(tag.tag)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(tag.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? Theme.accent.opacity(0.12) : Color.clear)
        .listRowInsets(edge)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if let user = viewModel.user {
                Text(user.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Menu {
                Button {
                    showNewCollection = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Button {
                    viewModel.openTagsManager()
                } label: {
                    Label("Manage Tags", systemImage: "tag")
                }
                Button {
                    viewModel.openImportExport()
                } label: {
                    Label("Import / Export", systemImage: "square.and.arrow.up.on.square")
                }
                Button {
                    viewModel.openQuickSave()
                } label: {
                    Label("Quick Save", systemImage: "square.and.arrow.down")
                }
                Divider()
                Button(role: .destructive) {
                    authService.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.hierarchical)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
