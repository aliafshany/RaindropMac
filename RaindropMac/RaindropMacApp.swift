// RaindropMacApp.swift
// App entry point - handles deep link redirect for OAuth

import SwiftUI

@main
struct RaindropMacApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var viewModel = AppViewModel()

    init() {
        // Larger URL cache → fewer network hits for covers/thumbnails (RAM-friendly disk cache)
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,  // 32 MB memory
            diskCapacity: 200 * 1024 * 1024,   // 200 MB disk
            diskPath: "raindrop_url_cache"
        )
    }

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
        .defaultSize(width: Theme.windowWidth, height: Theme.windowHeight)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Bookmark…") {
                    viewModel.openAddSheet()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Quick Save…") {
                    viewModel.openQuickSave()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

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
                Button(viewModel.isSelecting ? "Done Selecting" : "Select Multiple") {
                    viewModel.toggleSelecting()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                Divider()
                Button("Refresh") {
                    Task { await viewModel.sync() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Appearance") {
                ForEach(AppAppearance.allCases) { mode in
                    Button {
                        UserDefaults.standard.set(mode.rawValue, forKey: "appAppearance")
                    } label: {
                        if (UserDefaults.standard.string(forKey: "appAppearance") ?? "system") == mode.rawValue {
                            Label(mode.label, systemImage: "checkmark")
                        } else {
                            Text(mode.label)
                        }
                    }
                }
            }

            CommandMenu("Library") {
                Button("Manage Tags…") {
                    viewModel.openTagsManager()
                }
                Button("Import / Export…") {
                    viewModel.openImportExport()
                }
                Divider()
                Button("Broken links") {
                    viewModel.applySpecialFilter(.broken)
                }
                Button("Duplicates") {
                    viewModel.applySpecialFilter(.duplicates)
                }
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
                Button("Stella") {
                    Task { await viewModel.selectSystem(.stella) }
                }
                .keyboardShortcut("5", modifiers: [.command])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(authService)
        }
        #endif
    }

}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var authService: AuthService
    @AppStorage("client_id") private var clientId = ""
    @AppStorage("client_secret") private var clientSecret = ""
    @AppStorage("appAppearance") private var appearanceRaw = AppAppearance.system.rawValue

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        TabView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste your Raindrop integration credentials.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Link("Open integrations →", destination: URL(string: "https://app.raindrop.io/settings/integrations")!)
                            .font(.system(size: 12, weight: .medium))

                        Text("http://localhost:54321/auth/callback")
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.subtleFill)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .padding(.bottom, 4)

                    TextField("Client ID", text: $clientId)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .privacySensitive()

                    SecureField("Client Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .privacySensitive()

                    Text("Stored only on this Mac in app preferences — never committed to GitHub.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        clientId = ""
                        clientSecret = ""
                        authService.clearAllCredentials()
                    } label: {
                        Label("Clear credentials & sign out", systemImage: "trash")
                    }
                } header: {
                    Text("API Credentials")
                }
            }
            .formStyle(.grouped)
            .padding(12)
            .frame(width: 380, height: 360)
            .tabItem { Label("Account", systemImage: "key.fill") }

            Form {
                Section {
                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(AppAppearance.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("System follows macOS Light/Dark. Light and Dark lock the app theme.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Theme")
                }

                Section {
                    Picker("Library view", selection: $viewModel.viewMode) {
                        ForEach(ViewMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Also changeable from the toolbar. Saved automatically.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Library")
                }

                Section {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(Theme.accentSecondary)
                            .frame(width: 18, height: 18)
                        Text("Coral accent")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } header: {
                    Text("Colors")
                }
            }
            .formStyle(.grouped)
            .padding(12)
            .frame(width: 380, height: 340)
            .tabItem { Label("Appearance", systemImage: "paintbrush") }
            .preferredColorScheme(appearanceBinding.wrappedValue.colorScheme)

            Form {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 4)

                        Text("RaindropMac")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Version \(AppInfo.version) (\(AppInfo.build))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Text("A native SwiftUI client for Raindrop.io")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    LabeledContent("Author") {
                        Text("Ali Afshanisoumeeh")
                    }
                    LabeledContent("GitHub") {
                        Link("@aliafshany", destination: URL(string: "https://github.com/aliafshany")!)
                    }
                    LabeledContent("Repository") {
                        Link("RaindropMac", destination: URL(string: "https://github.com/aliafshany/RaindropMac")!)
                    }
                } header: {
                    Text("Credits")
                }

                Section {
                    Text("Unofficial third-party app. Not affiliated with Raindrop.io. Your bookmarks stay on your Raindrop account via the public API.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Disclaimer")
                }
            }
            .formStyle(.grouped)
            .padding(12)
            .frame(width: 380, height: 420)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .preferredColorScheme(appearanceBinding.wrappedValue.colorScheme)
    }
}

// MARK: - App info (version / build from the bundle)
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
