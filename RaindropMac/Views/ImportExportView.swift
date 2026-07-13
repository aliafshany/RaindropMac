// ImportExportView.swift
// Import HTML/URL lists · Export CSV/HTML

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImportExportView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var isWorking = false

    private func close() {
        viewModel.showImportExport = false
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import & Export")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                ModalCloseButton { close() }
            }
            .padding(16)

            Divider()

            Form {
                Section {
                    Text("Import Netscape HTML bookmarks or a plain list of URLs (one per line). Saved into the current collection (or Unsorted). Max 200 links per import.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await importFile() }
                    } label: {
                        Label(isWorking ? "Importing…" : "Import file…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isWorking)
                } header: {
                    Text("Import")
                }

                Section {
                    Button {
                        Task { await exportCSV() }
                    } label: {
                        Label("Export CSV…", systemImage: "tablecells")
                    }
                    .disabled(isWorking)

                    Button {
                        Task { await exportHTML() }
                    } label: {
                        Label("Export HTML bookmarks…", systemImage: "doc.richtext")
                    }
                    .disabled(isWorking)
                } header: {
                    Text("Export")
                }

                if !status.isEmpty {
                    Section {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(8)

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
    }

    private func importFile() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html, .plainText, .commaSeparatedText, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isWorking = true
        status = "Importing…"
        let count = await viewModel.importBookmarks(from: url)
        status = count > 0 ? "Imported \(count) bookmark(s)." : "No links found or import failed."
        isWorking = false
    }

    private func exportCSV() async {
        isWorking = true
        status = "Exporting CSV…"
        if let temp = await viewModel.exportLibraryCSV() {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "raindrop-export.csv"
            if panel.runModal() == .OK, let dest = panel.url {
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: temp, to: dest)
                status = "Saved CSV."
            } else {
                status = "Export cancelled."
            }
        }
        isWorking = false
    }

    private func exportHTML() async {
        isWorking = true
        status = "Exporting HTML…"
        if let temp = await viewModel.exportLibraryHTML() {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = "raindrop-export.html"
            if panel.runModal() == .OK, let dest = panel.url {
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: temp, to: dest)
                status = "Saved HTML bookmarks."
            } else {
                status = "Export cancelled."
            }
        }
        isWorking = false
    }
}
