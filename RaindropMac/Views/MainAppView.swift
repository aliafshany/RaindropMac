// MainAppView.swift
// Sidebar + content layout (bookmarks 3-column, Stella 2-column full pane)

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService
    @State private var selectedRaindrop: Raindrop?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    private var isStella: Bool {
        viewModel.selectedCollectionId == SystemCollection.stella.rawValue
    }

    var body: some View {
        Group {
            if isStella {
                stellaLayout
            } else {
                bookmarksLayout
            }
        }
        .onChange(of: viewModel.raindrops) { _, newValue in
            if let selected = selectedRaindrop, !newValue.contains(where: { $0.id == selected.id }) {
                selectedRaindrop = nil
            }
        }
        .onChange(of: viewModel.selectedCollectionId) { _, newId in
            selectedRaindrop = nil
            if newId == SystemCollection.stella.rawValue {
                columnVisibility = .all
            }
        }
        .onChange(of: viewModel.selectedTag) { _, _ in
            selectedRaindrop = nil
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddEditRaindropView(raindropToEdit: nil)
                .environmentObject(viewModel)
        }
        .sheet(item: $viewModel.editingRaindrop) { raindrop in
            AddEditRaindropView(raindropToEdit: raindrop)
                .environmentObject(viewModel)
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

    // MARK: - Bookmarks: Sidebar | List | Detail
    private var bookmarksLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } content: {
            RaindropsListView(selectedRaindrop: $selectedRaindrop)
                .navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 560)
        } detail: {
            if let selected = selectedRaindrop {
                let live = viewModel.raindrops.first(where: { $0.id == selected.id }) ?? selected
                RaindropDetailView(raindrop: live)
            } else {
                EmptyDetailView()
            }
        }
    }

    // MARK: - Stella: Sidebar | Full chat (no nested search / detail)
    private var stellaLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            StellaView(contextRaindropId: viewModel.stellaContextRaindropId)
                .environmentObject(viewModel)
                .navigationTitle("Stella")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            Task { await viewModel.selectSystem(.all) }
                        } label: {
                            Label("Library", systemImage: "bookmark.fill")
                        }
                        .help("Back to library")

                        Button {
                            viewModel.showAddSheet = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .help("Add bookmark (⌘N)")
                    }
                }
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        EmptyStateView(
            icon: "bookmark",
            title: "Select a bookmark",
            message: "Choose an item from the list to preview details, notes, and highlights."
        )
    }
}
