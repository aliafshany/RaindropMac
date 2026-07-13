// StellaView.swift
// Real Stella (official UI) — requires Raindrop web session (one-time sign-in)

import SwiftUI

struct StellaView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var bridge = StellaWebBridge()
    var contextRaindropId: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            ZStack {
                StellaWebView(
                    bridge: bridge,
                    raindropId: contextRaindropId,
                    onRaindropLink: { id in
                        // Jump back to library and search by id isn’t ideal — open all & hint
                        Task {
                            await viewModel.selectSystem(.all)
                            viewModel.searchQuery = String(id)
                        }
                    },
                    onCollectionLink: { id in
                        if let col = viewModel.collections.first(where: { $0.id == id }) {
                            Task { await viewModel.selectCollection(col) }
                        }
                    },
                    onTagLink: { tag in
                        Task {
                            await viewModel.selectSystem(.all)
                            await viewModel.selectTag(tag)
                        }
                    },
                    onToolCalled: {
                        Task { await viewModel.sync() }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if bridge.isLoading {
                    ProgressView("Loading Stella…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if bridge.needsLogin {
                    loginOverlay
                }

                if let err = bridge.lastError {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                            Text(err)
                                .font(.system(size: 12))
                            Button("Retry") {
                                bridge.reloadStella(raindropId: contextRaindropId)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding()
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: contextRaindropId) { _, newId in
            bridge.reloadStella(raindropId: newId)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Stella")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(contextRaindropId != nil ? "Asking about a bookmark · Pro AI" : "Your Raindrop AI · Pro")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if bridge.needsLogin {
                Button {
                    bridge.openLogin()
                } label: {
                    Label("Sign in to Stella", systemImage: "person.badge.key.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)
            } else {
                Button {
                    bridge.reloadStella(raindropId: contextRaindropId)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reload Stella")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Login overlay
    private var loginOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, Theme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Connect Stella")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Stella’s AI runs on Raindrop’s servers and needs a web session — your OAuth library login isn’t enough.\n\nSign in once with the same Raindrop account (Pro). We’ll keep the session so you stay connected.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                Button {
                    bridge.openLogin()
                } label: {
                    Label("Sign in with Raindrop", systemImage: "person.badge.key.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: 280)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Text("Use the same account as this app · Pro required")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        }
    }
}
