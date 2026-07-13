// RaindropDetailView.swift
// Compact cozy detail — designed for sheet presentation

import SwiftUI

struct RaindropDetailView: View {
    let raindrop: Raindrop
    var isSheet: Bool = false
    var onClose: (() -> Void)? = nil
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringOpen = false
    @State private var showDeleteConfirm = false

    private func closeSheet() {
        guard isSheet else { return }
        onClose?()
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSheet {
                sheetChrome
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    coverHeader

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(raindrop.displayTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .lineLimit(3)

                            Spacer(minLength: 6)

                            Button {
                                Task { await viewModel.toggleFavorite(raindrop) }
                            } label: {
                                Image(systemName: raindrop.important == true ? "star.fill" : "star")
                                    .font(.system(size: 15))
                                    .foregroundStyle(raindrop.important == true ? .yellow : .secondary)
                                    .symbolEffect(.bounce, value: raindrop.important == true)
                                    .frame(width: 30, height: 30)
                                    .background(Theme.subtleFill)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.9))
                            .tooltip(raindrop.important == true ? "Remove from favorites" : "Add to favorites")
                        }

                        FlowLayout(spacing: 6) {
                            metaChip(icon: "globe", text: raindrop.displayDomain)
                            if let type = raindrop.type, type != "link" {
                                metaChip(icon: raindrop.typeIcon, text: type.capitalized, color: raindrop.typeColor)
                            }
                            if let col = viewModel.collectionTitle(for: raindrop) {
                                metaChip(icon: "folder.fill", text: col)
                            }
                            if let created = raindrop.created {
                                metaChip(icon: "calendar", text: Theme.relativeDate(created))
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                viewModel.openInBrowser(raindrop)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Open")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    LinearGradient(
                                        colors: [Theme.accent, Theme.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(
                                    color: Theme.accent.opacity(isHoveringOpen ? 0.4 : 0.2),
                                    radius: isHoveringOpen ? 8 : 4,
                                    y: 2
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .tooltip("Open in browser")
                            .onHover { h in
                                withAnimation(Theme.press) { isHoveringOpen = h }
                            }

                            Button { viewModel.copyLink(raindrop) } label: {
                                actionIcon("link")
                            }
                            .tooltip("Copy link")
                            .buttonStyle(PressableButtonStyle(scale: 0.94))

                            Button {
                                viewModel.openReader(raindrop)
                            } label: {
                                actionIcon("doc.text.magnifyingglass")
                            }
                            .tooltip("Reader / permanent archive")
                            .buttonStyle(PressableButtonStyle(scale: 0.94))

                            Button { viewModel.openEditor(raindrop) } label: {
                                actionIcon("pencil")
                            }
                            .tooltip("Edit bookmark")
                            .buttonStyle(PressableButtonStyle(scale: 0.94))

                            Button {
                                viewModel.stellaContextRaindropId = raindrop.id
                                if isSheet { closeSheet() }
                                Task { await viewModel.selectSystem(.stella) }
                            } label: {
                                actionIcon("sparkles")
                            }
                            .tooltip("Ask Stella about this")
                            .buttonStyle(PressableButtonStyle(scale: 0.94))
                        }

                        if let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                            detailCard {
                                SectionLabel(title: "Description", icon: "text.alignleft")
                                Text(excerpt)
                                    .font(.system(size: 12))
                                    .lineSpacing(3)
                                    .textSelection(.enabled)
                                    .foregroundStyle(.primary.opacity(0.9))
                            }
                        }

                        if let tags = raindrop.tags, !tags.isEmpty {
                            detailCard {
                                SectionLabel(title: "Tags", icon: "tag")
                                FlowLayout(spacing: 5) {
                                    ForEach(tags, id: \.self) { tag in
                                        ModernChip(title: tag, icon: "number", color: Theme.accent) {
                                            if isSheet { closeSheet() }
                                            Task { await viewModel.selectTag(tag) }
                                        }
                                    }
                                }
                            }
                        }

                        if let note = raindrop.note, !note.isEmpty {
                            detailCard(tint: .orange) {
                                SectionLabel(title: "Note", icon: "note.text", color: .orange)
                                Text(note)
                                    .font(.system(size: 12))
                                    .lineSpacing(3)
                                    .textSelection(.enabled)
                            }
                        }

                        if let highlights = raindrop.highlights, !highlights.isEmpty {
                            detailCard(tint: .yellow) {
                                SectionLabel(title: "Highlights (\(highlights.count))", icon: "highlighter", color: .yellow)
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(highlights) { highlight in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(highlight.text)
                                                .font(.system(size: 12, weight: .medium))
                                                .padding(.leading, 8)
                                                .overlay(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(highlightColor(highlight.color))
                                                        .frame(width: 3)
                                                }
                                            if let hNote = highlight.note, !hNote.isEmpty {
                                                Text(hNote)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.leading, 8)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        detailCard {
                            SectionLabel(title: "Link", icon: "link")
                            Text(raindrop.link)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.accent)
                                .textSelection(.enabled)
                                .lineLimit(3)
                                .onTapGesture { viewModel.copyLink(raindrop) }
                        }

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(
                                viewModel.selectedCollectionId == -99 ? "Delete permanently" : "Move to Trash",
                                systemImage: "trash"
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Theme.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .id(raindrop.id)
        .confirmationDialog(
            viewModel.selectedCollectionId == -99 ? "Delete forever?" : "Move to Trash?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.selectedCollectionId == -99 ? "Delete" : "Move to Trash", role: .destructive) {
                Task { await viewModel.deleteRaindrop(raindrop) }
                if isSheet { closeSheet() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var sheetChrome: some View {
        HStack {
            Text("Bookmark")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            ModalCloseButton { closeSheet() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var coverHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = raindrop.coverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
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
            .frame(height: 48)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 120)
    }

    private var headerFallback: some View {
        LinearGradient(
            colors: [raindrop.typeColor.opacity(0.22), Theme.accentSecondary.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .overlay {
            Image(systemName: raindrop.typeIcon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(raindrop.typeColor.opacity(0.35))
        }
    }

    private func detailCard<Content: View>(tint: Color? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint?.opacity(0.07) ?? Theme.subtleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((tint ?? Color.primary).opacity(0.07), lineWidth: 1)
        )
    }

    private func metaChip(icon: String, text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func actionIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.75))
            .frame(width: 34, height: 34)
            .background(Theme.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
