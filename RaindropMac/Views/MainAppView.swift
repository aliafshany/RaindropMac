// MainAppView.swift
// Three-column layout: Sidebar | List | Detail

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService
    @State private var selectedRaindrop: Raindrop?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar (Collections)
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } content: {
            // MARK: - Middle Column (Raindrops List)
            RaindropsListView(selectedRaindrop: $selectedRaindrop)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            // MARK: - Detail Column
            if let raindrop = selectedRaindrop {
                RaindropDetailView(raindrop: raindrop)
            } else {
                EmptyDetailView()
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddEditRaindropView(raindropToEdit: nil)
                .environmentObject(viewModel)
        }
        .sheet(item: $viewModel.editingRaindrop) { raindrop in
            AddEditRaindropView(raindropToEdit: raindrop)
                .environmentObject(viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Empty Detail State
struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Select a Bookmark")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("Choose a raindrop from the list to view its details.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
