// AddRaindropView.swift
// Sheet for adding a new bookmark

import SwiftUI

struct AddEditRaindropView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    let raindropToEdit: Raindrop?
    
    @State private var url = ""
    @State private var title = ""
    @State private var tagsText = ""
    @State private var isProcessing = false
    @State private var urlError = false
    
    var isEditing: Bool { raindropToEdit != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit Bookmark" : "Add Bookmark")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(isEditing ? "Update link details" : "Save a new link to your collection")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // URL Field
                    FormField(label: "URL", systemImage: "link", isRequired: true, hasError: urlError) {
                        TextField("https://example.com", text: $url)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .onChange(of: url) { _, _ in urlError = false }
                            .onSubmit { saveBookmark() }
                    }

                    // Title Field
                    FormField(label: "Title", systemImage: "text.cursor", isRequired: false) {
                        TextField("Optional — auto-fetched if empty", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }

                    // Tags
                    FormField(label: "Tags", systemImage: "tag", isRequired: false) {
                        TextField("design, productivity, swift", text: $tagsText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }

                    // Collection indicator
                    if !isEditing, let col = viewModel.selectedCollection {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                            Text("Will be added to: \(col.title)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(24)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button {
                    saveBookmark()
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 14))
                        }
                        Text(isProcessing ? "Saving..." : (isEditing ? "Save Changes" : "Add Bookmark"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(url.isEmpty ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(url.isEmpty || isProcessing)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 440, height: 440)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let raindrop = raindropToEdit {
                url = raindrop.link
                title = raindrop.title
                tagsText = (raindrop.tags ?? []).joined(separator: ", ")
            }
        }
    }

    private func saveBookmark() {
        guard !url.isEmpty else { return }
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
            urlError = true
            return
        }

        let parsedTags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        isProcessing = true
        Task {
            if let raindrop = raindropToEdit {
                let colId = raindrop.collection?.id ?? -1
                await viewModel.updateRaindrop(raindrop, link: url, title: title.isEmpty ? nil : title, collectionId: colId, tags: parsedTags)
            } else {
                let colId = viewModel.selectedCollection?.id ?? -1
                await viewModel.addRaindrop(link: url, title: title.isEmpty ? nil : title, tags: parsedTags)
            }
            isProcessing = false
            dismiss()
        }
    }
}

// MARK: - Form Field Helper
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
                        .foregroundStyle(hasError ? .red : .accentColor)
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
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(hasError ? Color.red.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
