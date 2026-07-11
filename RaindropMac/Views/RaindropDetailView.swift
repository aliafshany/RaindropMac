// RaindropDetailView.swift
// Detail panel for a selected bookmark

import SwiftUI

struct RaindropDetailView: View {
    let raindrop: Raindrop
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isHoveringOpen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Cover image or gradient header
                ZStack(alignment: .bottomLeading) {
                    if let cover = raindrop.cover, !cover.isEmpty, let url = URL(string: cover) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                            default:
                                headerGradient
                            }
                        }
                    } else {
                        headerGradient
                    }

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, Color(NSColor.windowBackgroundColor).opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }

                // Content
                VStack(alignment: .leading, spacing: 20) {

                    // Title + Favorite
                    HStack(alignment: .top) {
                        Text(raindrop.title.isEmpty ? "Untitled" : raindrop.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(3)

                        Spacer()

                        Button {
                            Task { await viewModel.toggleFavorite(raindrop) }
                        } label: {
                            Image(systemName: raindrop.important == true ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundStyle(raindrop.important == true ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(raindrop.important == true ? "Remove from favorites" : "Add to favorites")
                    }

                    // Domain + Type badge
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text(raindrop.domain ?? extractDomain(from: raindrop.link))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        if let type = raindrop.type, type != "link" {
                            Text(type.capitalized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    // Open in browser button
                    Button {
                        if let url = URL(string: raindrop.link) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Open in Browser")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.accentColor, Color(red: 0.2, green: 0.3, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .accentColor.opacity(isHoveringOpen ? 0.5 : 0.25), radius: isHoveringOpen ? 12 : 6)
                        .scaleEffect(isHoveringOpen ? 1.01 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.spring(response: 0.2)) { isHoveringOpen = h }
                    }

                    Divider()

                    // Link
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Link", systemImage: "link")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(raindrop.link)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(2)
                            .textSelection(.enabled)
                            .onTapGesture {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(raindrop.link, forType: .string)
                            }
                    }

                    // Excerpt / Description
                    if let excerpt = raindrop.excerpt, !excerpt.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(excerpt)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                    }

                    // Tags
                    if let tags = raindrop.tags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Tags", systemImage: "tag")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            FlowLayout(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag.fill")
                                            .font(.system(size: 9))
                                        Text(tag)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Pro Feature: Note
                    if let note = raindrop.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Note", systemImage: "note.text")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                                .textCase(.uppercase)
                            
                            Text(note)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // Pro Feature: Highlights
                    if let highlights = raindrop.highlights, !highlights.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Highlights (\(highlights.count))", systemImage: "highlighter")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.yellow)
                                .textCase(.uppercase)
                            
                            ForEach(highlights) { highlight in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(highlight.text)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .padding(.leading, 10)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color.yellow)
                                                .frame(width: 3),
                                            alignment: .leading
                                        )
                                    
                                    if let hNote = highlight.note, !hNote.isEmpty {
                                        Text(hNote)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 10)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Pro Feature: Permanent Library (Cache)
                    if let cache = raindrop.cache, cache.status == "ready" {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Permanent Library", systemImage: "archivebox.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.purple)
                                .textCase(.uppercase)
                            
                            Button {
                                if let url = URL(string: "https://api.raindrop.io/rest/v1/raindrop/\(raindrop.id)/cache") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.down")
                                    Text("View Permanent Copy")
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.purple.opacity(0.1))
                                .foregroundStyle(.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Details", systemImage: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if let created = raindrop.created {
                            MetadataRow(label: "Saved", value: formatDate(created))
                        }
                        if let updated = raindrop.lastUpdate {
                            MetadataRow(label: "Updated", value: formatDate(updated))
                        }
                        MetadataRow(label: "ID", value: "\(raindrop.id)")
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .background(Color.clear)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.editingRaindrop = raindrop
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .help("Edit bookmark")
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    Task { await viewModel.deleteRaindrop(raindrop) }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .help("Delete bookmark")
            }
        }
    }

    // MARK: - Helpers
    private var headerGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.15),
                Color.accentColor.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .overlay {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor.opacity(0.3))
                .shadow(color: Color.accentColor.opacity(0.2), radius: 10)
        }
    }

    private func extractDomain(from urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return dateString
    }
}

// MARK: - Metadata Row
struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Simple Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
