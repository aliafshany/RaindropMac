// RaindropsListView.swift
// Middle column showing the list of bookmarks

import SwiftUI

struct RaindropsListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var selectedRaindrop: Raindrop?

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))

                TextField("Search bookmarks...", text: $viewModel.searchQuery)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if viewModel.selectedCollectionId == -2 {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    VStack(spacing: 4) {
                        Text("Ask Stella")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Stella is Raindrop's AI assistant. Pro feature.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        if let url = URL(string: "https://app.raindrop.io/") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open Web App")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                Spacer()
            } else {
                if viewModel.isLoading && viewModel.raindrops.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading bookmarks...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.displayedRaindrops.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: viewModel.searchQuery.isEmpty ? "bookmark.slash" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    VStack(spacing: 4) {
                        Text(viewModel.searchQuery.isEmpty ? "No bookmarks yet" : "No results found")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(viewModel.searchQuery.isEmpty ? "Add your first bookmark to this folder." : "Try adjusting your search terms.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            } else {
                List(viewModel.displayedRaindrops, selection: $selectedRaindrop) { raindrop in
                    RaindropRowView(raindrop: raindrop)
                        .tag(raindrop)
                        .contextMenu {
                            Button {
                                if let url = URL(string: raindrop.link) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("Open in Browser", systemImage: "safari")
                            }

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(raindrop.link, forType: .string)
                            } label: {
                                Label("Copy Link", systemImage: "link")
                            }

                            Button {
                                viewModel.editingRaindrop = raindrop
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                Task { await viewModel.deleteRaindrop(raindrop) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onAppear {
                            // Infinite scroll: load more when last item appears
                            if raindrop == viewModel.displayedRaindrops.last && viewModel.hasMore && !viewModel.isSearching {
                                Task { await viewModel.loadNextPage() }
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                if viewModel.isLoading && !viewModel.raindrops.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
            }
            }
        }
        .navigationTitle(viewModel.selectedCollectionId == -2 ? "Ask Stella" : (viewModel.selectedCollection?.title ?? "All Bookmarks"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if !viewModel.raindrops.isEmpty {
                        Text("\(viewModel.totalCount) bookmarks")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            .offset(y: 1) // Micro-adjustment for perfect vertical alignment with the button
                    }
                    
                    Button {
                        Task { await viewModel.sync() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .help("Sync Bookmarks (⌘R)")
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }
}

// MARK: - Raindrop Row
struct RaindropRowView: View {
    let raindrop: Raindrop
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Main Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    // Type icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: typeIcon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(raindrop.title.isEmpty ? raindrop.link : raindrop.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .foregroundStyle(.primary)

                        Text(raindrop.domain ?? extractDomain(from: raindrop.link))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()

                    if raindrop.important == true {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.4), radius: 2, y: 1)
                    }
                }

                // Tags
                if let tags = raindrop.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.unemphasizedSelectedContentBackgroundColor).opacity(0.5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Excerpt
                if let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            // Cover Thumbnail
            if let cover = raindrop.cover, !cover.isEmpty, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    case .empty:
                        ProgressView().frame(width: 60, height: 60)
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? .ultraThinMaterial : .ultraThinMaterial)
                .opacity(isHovering ? 1.0 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isHovering ? 0.3 : 0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 8 : 4, y: isHovering ? 4 : 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var typeIcon: String {
        switch raindrop.type {
        case "image": return "photo"
        case "video": return "play.rectangle"
        case "article": return "doc.text"
        case "audio": return "music.note"
        default: return "link"
        }
    }

    private func extractDomain(from urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
