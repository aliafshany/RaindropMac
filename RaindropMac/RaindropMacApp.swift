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
                    // Handle OAuth redirect: raindropswift://auth?code=...
                    authService.handleRedirect(url: url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Bookmark...") {
                    viewModel.showAddSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("client_id") private var clientId = ""
    @AppStorage("client_secret") private var clientSecret = ""
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To use this app, you must create an integration on Raindrop.io.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Link("1. Go to Raindrop Integrations", destination: URL(string: "https://app.raindrop.io/settings/integrations")!)
                        .font(.subheadline)
                    Text("2. Create a new app and set Redirect URI to:")
                        .font(.subheadline)
                    Text("http://localhost:54321/auth/callback")
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    Text("3. Paste the Client ID and Secret below:")
                        .font(.subheadline)
                }
                .padding(.bottom, 10)
                
                TextField("Client ID", text: $clientId)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 350)
                
                SecureField("Client Secret", text: $clientSecret)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 350)
            } header: {
                Text("API Credentials").font(.headline)
            }
            .padding()
        }
        .padding(20)
        .frame(width: 450, height: 320)
    }
}
