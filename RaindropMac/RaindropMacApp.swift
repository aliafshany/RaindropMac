// RaindropMacApp.swift
// App entry point - handles deep link redirect for OAuth

import SwiftUI

@main
struct RaindropMacApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(viewModel)
                .onOpenURL { url in
                    authService.handleRedirect(url: url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Bookmark…") {
                    viewModel.showAddSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Collection…") {
                    viewModel.showNewCollectionSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("View") {
                ForEach(ViewMode.allCases) { mode in
                    Button(mode.label) {
                        viewModel.viewMode = mode
                    }
                }
                Divider()
                Button("Refresh") {
                    Task { await viewModel.sync() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Go") {
                Button("All Bookmarks") {
                    Task { await viewModel.selectSystem(.all) }
                }
                .keyboardShortcut("1", modifiers: [.command])
                Button("Favorites") {
                    Task { await viewModel.selectSystem(.favorites) }
                }
                .keyboardShortcut("2", modifiers: [.command])
                Button("Unsorted") {
                    Task { await viewModel.selectSystem(.unsorted) }
                }
                .keyboardShortcut("3", modifiers: [.command])
                Button("Trash") {
                    Task { await viewModel.selectSystem(.trash) }
                }
                .keyboardShortcut("4", modifiers: [.command])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

}

// MARK: - Settings
struct SettingsView: View {
    @AppStorage("client_id") private var clientId = ""
    @AppStorage("client_secret") private var clientSecret = ""
    @AppStorage("viewMode") private var viewModeRaw = ViewMode.list.rawValue

    var body: some View {
        TabView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Create an integration on Raindrop.io, then paste credentials here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Link("Open Raindrop Integrations →", destination: URL(string: "https://app.raindrop.io/settings/integrations")!)
                            .font(.subheadline)

                        Text("Redirect URI must be:")
                            .font(.subheadline)
                        Text("http://localhost:54321/auth/callback")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.bottom, 6)

                    TextField("Client ID", text: $clientId)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Client Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("API Credentials")
                }
            }
            .formStyle(.grouped)
            .padding()
            .frame(width: 480, height: 340)
            .tabItem { Label("Account", systemImage: "key.fill") }

            Form {
                Picker("Default view", selection: $viewModeRaw) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .frame(width: 480, height: 200)
            .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
    }
}
