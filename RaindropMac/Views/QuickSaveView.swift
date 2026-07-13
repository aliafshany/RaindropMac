// QuickSaveView.swift
// Fast paste-URL save sheet — fixed header/footer, scrollable body, single-line URL

import SwiftUI
import AppKit

struct QuickSaveView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var url = ""
    @State private var title = ""
    @State private var tagsText = ""
    @State private var collectionId: Int = -1
    @State private var important = false
    @State private var isSaving = false
    @State private var isSuggesting = false
    @FocusState private var focusedField: Field?

    private enum Field { case url, title, tags }

    private func close() {
        viewModel.showQuickSave = false
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header — never clipped
            header
            Divider()

            // Scrollable middle — always can reach bottom fields
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField("URL", required: true) {
                        // Single-line URL: no mid-word wrap; scrolls horizontally if needed
                        TextField("https://example.com", text: $url)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .default))
                            .lineLimit(1)
                            .focused($focusedField, equals: .url)
                            .onSubmit { focusedField = .title }
                    }

                    labeledField("Title") {
                        TextField("Optional — fetched if empty", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .focused($focusedField, equals: .title)
                            .onSubmit { focusedField = .tags }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("COLLECTION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                    }

                    labeledField("Tags") {
                        TextField("design, reading, …", text: $tagsText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .focused($focusedField, equals: .tags)
                            .onSubmit { save() }
                    }

                    Toggle(isOn: $important) {
                        Label("Mark as favorite", systemImage: "star.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .tint(.yellow)
                    .padding(.top, 2)

                    if canSave {
                        Button {
                            Task { await suggest() }
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.98))
                        .disabled(isSuggesting)
                        .help("Ask Raindrop for tag and collection suggestions")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Fixed footer — always visible
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
        .onAppear {
            if let clip = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               clip.hasPrefix("http://") || clip.hasPrefix("https://") {
                url = clip
            }
            collectionId = viewModel.selectedCollection?.id ?? -1
            if collectionId == 0 || collectionId < -1 { collectionId = -1 }
            focusedField = .url
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Quick Save")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Paste a link and save to your library")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ModalCloseButton { close() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Cancel") { close() }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                .controlSize(.regular)

            Spacer()

            Button {
                save()
            } label: {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isSaving ? "Saving…" : "Save")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(canSave ? Theme.accent : Theme.accent.opacity(0.4))
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSave || isSaving)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Save bookmark (⌘↩)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func labeledField<Content: View>(
        _ title: String,
        required: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if required {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }

            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        }
    }

    private var canSave: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func suggest() async {
        var link = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !link.hasPrefix("http") { link = "https://\(link)" }
        isSuggesting = true
        do {
            let item = try await APIService.shared.suggest(for: link)
            if let tags = item.tags, !tags.isEmpty {
                tagsText = tags.joined(separator: ", ")
            }
            if let id = item.collections?.first?.id {
                collectionId = id
            }
        } catch { /* ignore */ }
        isSuggesting = false
    }

    private func save() {
        var link = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return }
        if !link.hasPrefix("http://") && !link.hasPrefix("https://") {
            link = "https://\(link)"
        }
        let tags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        isSaving = true
        Task {
            await viewModel.addRaindrop(
                link: link,
                title: title.isEmpty ? nil : title,
                tags: tags,
                collectionId: collectionId,
                important: important
            )
            isSaving = false
            close()
        }
    }
}
