// RaindropDetailView.swift
// Polished detail panel for a selected bookmark

import SwiftUI

struct RaindropDetailView: View {
    let raindrop: Raindrop
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isHoveringOpen = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                coverHeader

                VStack(alignment: .leading, spacing: 20) {
                    // Title row
                    HStack(alignment: .top, spacing: 12) {
                        Text(raindrop.displayTitle)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineLimit(4)

                        Spacer(minLength: 8)

                        Button {
                            Task { await viewModel.toggleFavorite(raindrop) }
                        } label: {
                            Image(systemName: raindrop.important == true ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundStyle(raindrop.important == true ? .yellow : .secondary)
                                .frame(width: 36, height: 36)
                                .background(Theme.subtleFill)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(raindrop.important == true ? "Remove from favorites" : "Add to favorites")
                    }

                    // Meta chips
                    FlowLayout(spacing: 8) {
                        metaChip(icon: "globe", text: raindrop.displayDomain)
                        if let type = raindrop.type, type != "link" {
                            metaChip(icon: raindrop.typeIcon, text: type.capitalized, color: raindrop.typeColor)
                        }
                        if let col = viewModel.collectionTitle(for: raindrop) {
                            metaChip(icon: "folder.fill", text: col)
                        }
                        if let created = raindrop.created {
                            metaChip(icon: "calendar", text: Theme.formatDate(created))
                        }
                    }

                    // Primary actions
                    HStack(spacing: 10) {
                        Button {
                            viewModel.openInBrowser(raindrop)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Open")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Theme.accent.opacity(isHoveringOpen ? 0.45 : 0.22), radius: isHoveringOpen ? 12 : 6, y: 3)
                            .scaleEffect(isHoveringOpen ? 1.01 : 1)
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2)) { isHoveringOpen = h }
                        }

                        Button { viewModel.copyLink(raindrop) } label: {
                            actionIcon("link")
                        }
                        .help("Copy link")
                        .buttonStyle(.plain)

                        Button { viewModel.editingRaindrop = raindrop } label: {
                            actionIcon("pencil")
                        }
                        .help("Edit")
                        .buttonStyle(.plain)

                        Button {
                            viewModel.stellaContextRaindropId = raindrop.id
                            Task { await viewModel.selectSystem(.stella) }
                        } label: {
                            actionIcon("sparkles")
                        }
                        .help("Ask Stella about this")
                        .buttonStyle(.plain)
                    }

                    // Link
                    detailCard {
                        SectionLabel(title: "Link", icon: "link")
                        Text(raindrop.link)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .onTapGesture { viewModel.copyLink(raindrop) }
                    }

                    // Excerpt
                    if let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                        detailCard {
                            SectionLabel(title: "Description", icon: "text.alignleft")
                            Text(excerpt)
                                .font(.system(size: 13))
                                .lineSpacing(4)
                                .textSelection(.enabled)
                                .foregroundStyle(.primary.opacity(0.9))
                        }
                    }

                    // Tags
                    if let tags = raindrop.tags, !tags.isEmpty {
                        detailCard {
                            SectionLabel(title: "Tags", icon: "tag")
                            FlowLayout(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    ModernChip(title: tag, icon: "number", color: Theme.accent) {
                                        Task { await viewModel.selectTag(tag) }
                                    }
                                }
                            }
                        }
                    }

                    // Note
                    if let note = raindrop.note, !note.isEmpty {
                        detailCard(tint: .orange) {
                            SectionLabel(title: "Note", icon: "note.text", color: .orange)
                            Text(note)
                                .font(.system(size: 13))
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                    }

                    // Highlights
                    if let highlights = raindrop.highlights, !highlights.isEmpty {
                        detailCard(tint: .yellow) {
                            SectionLabel(title: "Highlights (\(highlights.count))", icon: "highlighter", color: .yellow)
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(highlights) { highlight in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(highlight.text)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.leading, 10)
                                            .overlay(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(highlightColor(highlight.color))
                                                    .frame(width: 3)
                                            }
                                        if let hNote = highlight.note, !hNote.isEmpty {
                                            Text(hNote)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .padding(.leading, 10)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Permanent library
                    if let cache = raindrop.cache, cache.status == "ready" {
                        detailCard(tint: .purple) {
                            SectionLabel(title: "Permanent Library", icon: "archivebox.fill", color: .purple)
                            Button {
                                if let url = URL(string: "https://api.raindrop.io/rest/v1/raindrop/\(raindrop.id)/cache") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("View permanent copy", systemImage: "icloud.and.arrow.down")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.purple)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.purple.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Details
                    detailCard {
                        SectionLabel(title: "Details", icon: "info.circle")
                        VStack(spacing: 8) {
                            MetadataRow(label: "Saved", value: Theme.formatDate(raindrop.created))
                            MetadataRow(label: "Updated", value: Theme.formatDate(raindrop.lastUpdate))
                            MetadataRow(label: "ID", value: "\(raindrop.id)")
                            if let type = raindrop.type {
                                MetadataRow(label: "Type", value: type.capitalized)
                            }
                        }
                    }

                    // Danger zone
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(
                            viewModel.selectedCollectionId == -99 ? "Delete permanently" : "Move to Trash",
                            systemImage: "trash"
                        )
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
            }
        }
        .background(Color.clear)
        .confirmationDialog(
            viewModel.selectedCollectionId == -99 ? "Delete forever?" : "Move to Trash?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.selectedCollectionId == -99 ? "Delete" : "Move to Trash", role: .destructive) {
                Task { await viewModel.deleteRaindrop(raindrop) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Cover
    private var coverHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let cover = raindrop.cover, !cover.isEmpty, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 210)
                            .clipped()
                    default:
                        headerFallback
                    }
                }
            } else {
                headerFallback
            }

            LinearGradient(
                colors: [.clear, Color(nsColor: .windowBackgroundColor).opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 90)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 210)
    }

    private var headerFallback: some View {
        LinearGradient(
            colors: [raindrop.typeColor.opacity(0.25), Theme.accentSecondary.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .overlay {
            Image(systemName: raindrop.typeIcon)
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(raindrop.typeColor.opacity(0.35))
        }
    }

    // MARK: - Helpers
    private func detailCard<Content: View>(tint: Color? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint?.opacity(0.07) ?? Theme.subtleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((tint ?? Color.primary).opacity(0.08), lineWidth: 1)
        )
    }

    private func metaChip(icon: String, text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func actionIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.75))
            .frame(width: 40, height: 40)
            .background(Theme.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func highlightColor(_ color: String?) -> Color {
        switch color {
        case "yellow", "default", nil: return .yellow
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        default: return .yellow
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
