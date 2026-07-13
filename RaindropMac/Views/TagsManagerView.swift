// TagsManagerView.swift
// Rename / delete tags

import SwiftUI

struct TagsManagerView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var renameFrom: String?
    @State private var renameTo = ""
    @State private var deleteTag: String?

    private func close() {
        viewModel.showTagsManager = false
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tags")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                ModalCloseButton { close() }
            }
            .padding(16)

            Divider()

            if viewModel.tags.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No tags yet",
                    message: "Tags appear as you save bookmarks with tags."
                )
            } else {
                List {
                    ForEach(viewModel.tags) { tag in
                        HStack {
                            Image(systemName: "number")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 16)
                            Text(tag.tag)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(tag.count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                renameFrom = tag.tag
                                renameTo = tag.tag
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("Rename")
                            Button(role: .destructive) {
                                deleteTag = tag.tag
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete tag")
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { close() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
        .alert("Rename tag", isPresented: Binding(
            get: { renameFrom != nil },
            set: { if !$0 { renameFrom = nil } }
        )) {
            TextField("New name", text: $renameTo)
            Button("Cancel", role: .cancel) { renameFrom = nil }
            Button("Save") {
                if let old = renameFrom {
                    let neu = renameTo.trimmingCharacters(in: .whitespaces)
                    guard !neu.isEmpty, neu != old else { return }
                    Task { await viewModel.renameTag(from: old, to: neu) }
                }
                renameFrom = nil
            }
        }
        .alert("Delete tag?", isPresented: Binding(
            get: { deleteTag != nil },
            set: { if !$0 { deleteTag = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTag = nil }
            Button("Delete", role: .destructive) {
                if let t = deleteTag {
                    Task { await viewModel.deleteTag(t) }
                }
                deleteTag = nil
            }
        } message: {
            Text("Removes “\(deleteTag ?? "")” from all bookmarks.")
        }
    }
}
