// ContentView.swift
// Root view — light / dark / system appearance

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var viewModel: AppViewModel
    @AppStorage("appAppearance") private var appearanceRaw = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainAppView()
                    .task { await viewModel.loadInitialData() }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        )
                    )
            } else {
                LoginView()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(Theme.easeOut, value: authService.isAuthenticated)
        .preferredColorScheme(appearance.colorScheme)
        .frame(
            minWidth: Theme.windowMinWidth,
            idealWidth: Theme.windowWidth,
            minHeight: Theme.windowMinHeight,
            idealHeight: Theme.windowHeight
        )
    }
}
