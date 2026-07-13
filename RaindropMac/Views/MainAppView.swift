// MainAppView.swift
// Collapsible sidebar (folders always visible) + tight content chrome

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService
    @State private var selectedRaindrop: Raindrop?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var isStella: Bool {
        viewModel.selectedCollectionId == SystemCollection.stella.rawValue
    }

    private var isSidebarOpen: Bool {
        columnVisibility != .detailOnly
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: Theme.sidebarMin,
                    ideal: Theme.sidebarIdeal,
                    max: Theme.sidebarMax
                )
        } detail: {
            Group {
                if isStella {
                    StellaView(contextRaindropId: viewModel.stellaContextRaindropId)
                        .environmentObject(viewModel)
                        .navigationTitle("Stella")
                } else {
                    RaindropsListView(selectedRaindrop: $selectedRaindrop)
                }
            }
            // Primary actions only — NO custom sidebar button.
            // NavigationSplitView already provides ONE system sidebar toggle.
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !isStella {
                        Button {
                            viewModel.toggleSelecting()
                        } label: {
                            toolbarGlyph(viewModel.isSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                        }
                        .tooltip(viewModel.isSelecting ? "Done selecting" : "Select multiple (⌘⇧A)")

                        // Menus: no hover tooltip — the open menu already labels each option
                        Menu {
                            ForEach(SortOption.allCases) { option in
                                Button {
                                    viewModel.sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.label)
                                        if viewModel.sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            toolbarGlyph("arrow.up.arrow.down")
                        }
                        .menuIndicator(.hidden)
                        .help("Sort") // system accessibility only; no floating bubble

                        Menu {
                            ForEach(ViewMode.allCases) { mode in
                                Button {
                                    viewModel.viewMode = mode
                                } label: {
                                    if viewModel.viewMode == mode {
                                        Label(mode.label, systemImage: "checkmark")
                                    } else {
                                        Label(mode.label, systemImage: mode.icon)
                                    }
                                }
                            }
                        } label: {
                            toolbarGlyph(viewModel.viewMode.icon)
                        }
                        .menuIndicator(.hidden)
                        .help("View mode")
                    } else {
                        Button {
                            Task { await viewModel.selectSystem(.all) }
                        } label: {
                            toolbarGlyph("bookmark.fill")
                        }
                        .tooltip("Back to library")
                    }

                    Button {
                        Task { await viewModel.sync() }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 28, height: 28)
                        } else {
                            toolbarGlyph("arrow.triangle.2.circlepath")
                        }
                    }
                    .tooltip("Sync library (⌘R)")
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(viewModel.isRefreshing || viewModel.isLoading)

                    Button {
                        viewModel.openQuickSave()
                    } label: {
                        toolbarGlyph("square.and.arrow.down")
                    }
                    .tooltip("Quick Save — paste a URL (⌘⇧S)")

                    Button {
                        viewModel.openAddSheet()
                    } label: {
                        toolbarGlyph("plus")
                    }
                    .tooltip("Add bookmark (⌘N)")
                }
            }
            // Invisible handler keeps ⌘\ without a second toolbar icon
            .background {
                Button("") {
                    withAnimation(Theme.snappy) {
                        columnVisibility = isSidebarOpen ? .detailOnly : .all
                    }
                }
                .keyboardShortcut("\\", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: viewModel.raindrops) { _, newValue in
            if let selected = selectedRaindrop, !newValue.contains(where: { $0.id == selected.id }) {
                selectedRaindrop = nil
            }
        }
        .onChange(of: viewModel.selectedCollectionId) { _, _ in
            selectedRaindrop = nil
        }
        .onChange(of: viewModel.selectedTag) { _, _ in
            selectedRaindrop = nil
        }
        // Click-outside dismisses (incl. title bar) via ScrimModal’s event monitor
        .scrimModal(isPresented: $viewModel.showQuickSave, width: 440, height: 480) {
            QuickSaveView()
                .environmentObject(viewModel)
        }
        .scrimModal(isPresented: $viewModel.showAddSheet, width: Theme.sheetWidth, height: Theme.sheetHeight) {
            AddEditRaindropView(raindropToEdit: nil)
                .environmentObject(viewModel)
        }
        .scrimModal(isPresented: $viewModel.showTagsManager, width: 400, height: 480) {
            TagsManagerView()
                .environmentObject(viewModel)
        }
        .scrimModal(isPresented: $viewModel.showImportExport, width: 420, height: 380) {
            ImportExportView()
                .environmentObject(viewModel)
        }
        .overlay {
            if let raindrop = viewModel.editingRaindrop {
                ScrimModal(
                    isPresented: Binding(
                        get: { viewModel.editingRaindrop != nil },
                        set: { if !$0 { viewModel.editingRaindrop = nil } }
                    ),
                    width: Theme.sheetWidth,
                    height: Theme.sheetHeight
                ) {
                    AddEditRaindropView(raindropToEdit: raindrop)
                        .environmentObject(viewModel)
                }
            }
        }
        .overlay {
            if let raindrop = selectedRaindrop {
                let live = viewModel.raindrops.first(where: { $0.id == raindrop.id }) ?? raindrop
                ScrimModal(
                    isPresented: Binding(
                        get: { selectedRaindrop != nil },
                        set: { if !$0 { selectedRaindrop = nil } }
                    ),
                    width: Theme.sheetWidth,
                    height: Theme.sheetHeight
                ) {
                    RaindropDetailView(
                        raindrop: live,
                        isSheet: true,
                        onClose: { selectedRaindrop = nil }
                    )
                    .environmentObject(viewModel)
                }
            }
        }
        .overlay {
            if let raindrop = viewModel.readerRaindrop {
                ScrimModal(
                    isPresented: Binding(
                        get: { viewModel.readerRaindrop != nil },
                        set: { if !$0 { viewModel.readerRaindrop = nil } }
                    ),
                    width: 780,
                    height: 560
                ) {
                    ReaderView(raindrop: raindrop)
                        .environmentObject(viewModel)
                }
            }
        }
        // Opening detail should not stack under another modal
        .onChange(of: selectedRaindrop?.id) { _, newId in
            if newId != nil {
                viewModel.showQuickSave = false
                viewModel.showAddSheet = false
                viewModel.showTagsManager = false
                viewModel.showImportExport = false
                viewModel.editingRaindrop = nil
                viewModel.readerRaindrop = nil
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// Shared glyph metrics so every toolbar icon shares the same baseline/box.
    private func toolbarGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .imageScale(.medium)
            .frame(width: 28, height: 28, alignment: .center)
            .contentShape(Rectangle())
    }
}

struct EmptyDetailView: View {
    var body: some View {
        EmptyStateView(
            icon: "bookmark",
            title: "Your library",
            message: "Pick a drop from the list."
        )
    }
}
