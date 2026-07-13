// ContentView.swift
// Root view - shows login or main app based on auth state

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainAppView()
                    .task { await viewModel.loadInitialData() }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authService.isAuthenticated)
        .frame(minWidth: 900, minHeight: 560)
    }
}
