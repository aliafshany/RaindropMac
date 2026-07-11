// SidebarView.swift
// Collections sidebar with user profile

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService
    
    @AppStorage("isCollectionsExpanded") private var isCollectionsExpanded = true
    @AppStorage("isTagsExpanded") private var isTagsExpanded = true

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedCollectionId },
            set: { newId in
                if let id = newId {
                    let col = viewModel.collections.first { $0.id == id }
                    Task { await viewModel.loadCollection(id: id, collection: col) }
                }
            }
        )) {
            // MARK: - User Header
            if let user = viewModel.user {
                UserHeaderView(user: user)
            }

            Divider().listRowInsets(EdgeInsets()).listRowSeparator(.hidden)

            // MARK: - Core
            Section {
                SidebarRow(icon: "bookmark.fill", iconColor: .blue, title: "All Bookmarks", count: viewModel.totalCount, isSelected: viewModel.selectedCollectionId == 0)
                    .tag(0)

                SidebarRow(icon: "archivebox.fill", iconColor: .gray, title: "Unsorted", count: 0, isSelected: viewModel.selectedCollectionId == -1) // API gives count in /user but we can keep it 0 here for now or omit
                    .tag(-1)
                
                SidebarRow(icon: "trash.fill", iconColor: .gray, title: "Trash", count: 0, isSelected: viewModel.selectedCollectionId == -99)
                    .tag(-99)
            }
            
            // MARK: - AI Features
            Section {
                SidebarRow(icon: "sparkles", iconColor: .purple, title: "Ask Stella (AI)", count: 0, isSelected: viewModel.selectedCollectionId == -2)
                    .tag(-2)
            }

            // MARK: - Collections
            if !viewModel.rootCollections.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $isCollectionsExpanded) {
                        ForEach(viewModel.rootCollections) { collection in
                            CollectionRow(collection: collection, viewModel: viewModel)
                        }
                    } label: {
                        Text("Collections")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // MARK: - Tags
            if !viewModel.tags.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $isTagsExpanded) {
                        ForEach(viewModel.tags) { tag in
                            SidebarRow(icon: "number", iconColor: .gray, title: tag.tag, count: tag.count, isSelected: false)
                                .tag(tag.hashValue)
                                .disabled(true) // Just visual for now
                        }
                    } label: {
                        Text("Tags")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add new bookmark (⌘N)")
            }

            ToolbarItem(placement: .destructiveAction) {
                Menu {
                    Button(role: .destructive) {
                        authService.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationTitle("Raindrop")
        .onAppear {
            Task { await viewModel.loadTags() }
        }
    }
}

// MARK: - Subviews
struct UserHeaderView: View {
    let user: User
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Text(String(user.name.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                HStack(spacing: 4) {
                    if user.pro {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                        Text("Pro").font(.system(size: 10, weight: .medium)).foregroundStyle(.yellow)
                    } else {
                        Text(user.email).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        .listRowSeparator(.hidden)
    }
}

struct CollectionRow: View {
    let collection: RaindropCollection
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        let children = viewModel.children(for: collection)
        
        if children.isEmpty {
            SidebarRow(
                icon: "folder.fill",
                iconColor: colorFromHex(collection.color) ?? .blue,
                title: collection.title,
                count: collection.count,
                isSelected: viewModel.selectedCollectionId == collection.id
            )
            .tag(collection.id)
        } else {
            DisclosureGroup(
                content: {
                    ForEach(children) { child in
                        CollectionRow(collection: child, viewModel: viewModel)
                    }
                },
                label: {
                    SidebarRow(
                        icon: "folder.fill",
                        iconColor: colorFromHex(collection.color) ?? .blue,
                        title: collection.title,
                        count: collection.count,
                        isSelected: viewModel.selectedCollectionId == collection.id
                    )
                }
            )
            .tag(collection.id)
        }
    }
    
    private func colorFromHex(_ hex: String?) -> Color? {
        guard let hex = hex else { return nil }
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let rgb = UInt64(h, radix: 16) else { return nil }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

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
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 16)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
        }
    }
}
