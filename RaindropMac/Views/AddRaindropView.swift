// AddRaindropView.swift
// Sheet for adding / editing bookmarks

import SwiftUI

struct AddEditRaindropView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    let raindropToEdit: Raindrop?

    @State private var url = ""
    @State private var title = ""
    @State private var tagsText = ""
    @State private var note = ""
    @State private var important = false
    @State private var collectionId: Int = -1
    @State private var isProcessing = false
    @State private var isSuggesting = false
    @State private var urlError = false
    @State private var suggestedTags: [String] = []

    var isEditing: Bool { raindropToEdit != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit Bookmark" : "Add Bookmark")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(isEditing ? "Update details, tags, and notes" : "Save a link to your library")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormField(label: "URL", systemImage: "link", isRequired: true, hasError: urlError) {
                        TextField("https://example.com", text: $url)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .onChange(of: url) { _, _ in
                                urlError = false
                            }
                            .onSubmit { saveBookmark() }
                    }

                    // Suggest button
                    if !isEditing && !url.isEmpty {
                        Button {
                            Task { await fetchSuggestions() }
                        } label: {
                            HStack(spacing: 6) {
                                if isSuggesting {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isSuggesting ? "Suggesting…" : "Suggest tags & collection")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSuggesting)
                    }

                    FormField(label: "Title", systemImage: "text.cursor", isRequired: false) {
                        TextField("Optional — auto-fetched if empty", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }

                    // Collection picker
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: "Collection", icon: "folder")
                        Picker("Collection", selection: $collectionId) {
                            Text("Unsorted").tag(-1)
                            ForEach(viewModel.rootCollections) { col in
                                Text(col.title).tag(col.id)
                                ForEach(viewModel.children(for: col)) { child in
                                    Text("  \(child.title)").tag(child.id)
                                }
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                    }

                    FormField(label: "Tags", systemImage: "tag", isRequired: false) {
                        TextField("design, productivity, swift", text: $tagsText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }

                    if !suggestedTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                ModernChip(title: tag, icon: "plus", color: Theme.accent) {
                                    appendTag(tag)
                                }
                            }
                        }
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: "Note", icon: "note.text")
                        TextEditor(text: $note)
                            .font(.system(size: 13))
                            .frame(minHeight: 72, maxHeight: 120)
                            .padding(8)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.hairline, lineWidth: 1)
                            )
                    }

                    // Favorite toggle
                    Toggle(isOn: $important) {
                        Label("Mark as favorite", systemImage: "star.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .tint(.yellow)
                }
                .padding(24)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Spacer()

                Button { saveBookmark() } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                        }
                        Text(isProcessing ? "Saving…" : (isEditing ? "Save Changes" : "Add Bookmark"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(url.isEmpty ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(url.isEmpty || isProcessing)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 460, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let raindrop = raindropToEdit {
                url = raindrop.link
                title = raindrop.title
                tagsText = (raindrop.tags ?? []).joined(separator: ", ")
                note = raindrop.note ?? ""
                important = raindrop.important ?? false
                collectionId = raindrop.collection?.id ?? -1
            } else {
                collectionId = viewModel.selectedCollection?.id ?? -1
                if collectionId == 0 || collectionId < -1 { collectionId = -1 }
            }
        }
    }

    private func appendTag(_ tag: String) {
        let existing = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !existing.contains(tag) else { return }
        if tagsText.trimmingCharacters(in: .whitespaces).isEmpty {
            tagsText = tag
        } else {
            tagsText += ", \(tag)"
        }
        suggestedTags.removeAll { $0 == tag }
    }

    private func fetchSuggestions() async {
        guard url.hasPrefix("http") else {
            urlError = true
            return
        }
        isSuggesting = true
        do {
            let item = try await APIService.shared.suggest(for: url)
            suggestedTags = item.tags ?? []
            if let firstCol = item.collections?.first?.id {
                collectionId = firstCol
            }
        } catch {
            // silent
        }
        isSuggesting = false
    }

    private func saveBookmark() {
        guard !url.isEmpty else { return }
        var finalURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://\(finalURL)"
        }
        url = finalURL

        let parsedTags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        isProcessing = true
        Task {
            if let raindrop = raindropToEdit {
                await viewModel.updateRaindrop(
                    raindrop,
                    link: finalURL,
                    title: title.isEmpty ? nil : title,
                    collectionId: collectionId,
                    tags: parsedTags,
                    note: note,
                    important: important
                )
            } else {
                await viewModel.addRaindrop(
                    link: finalURL,
                    title: title.isEmpty ? nil : title,
                    tags: parsedTags,
                    collectionId: collectionId,
                    note: note.isEmpty ? nil : note,
                    important: important
                )
            }
            isProcessing = false
            dismiss()
        }
    }
}

// MARK: - Form Field
struct FormField<Content: View>: View {
    let label: String
    let systemImage: String
    let isRequired: Bool
    var hasError: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hasError ? .red : .secondary)
                    .textCase(.uppercase)
                if isRequired {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(hasError ? .red : Theme.accent)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(hasError ? .red : .secondary)
                    .frame(width: 16)
                content
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(hasError ? Color.red.opacity(0.5) : Theme.hairline, lineWidth: 1)
            )
        }
    }
}
