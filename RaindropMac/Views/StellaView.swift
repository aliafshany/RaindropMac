// StellaView.swift
// Native Stella chat (StellaService) with browser fallback when API auth fails

import SwiftUI
import AppKit

struct StellaView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var stella = StellaChatViewModel()
    var contextRaindropId: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)

            switch stella.sessionState {
            case .checking:
                checkingState
            case .notPro:
                notProState
            case .needsBrowserFallback(let reason):
                browserFallbackState(reason: reason)
            case .ready:
                nativeChat
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            stella.bootstrap(raindropId: contextRaindropId)
        }
        .onChange(of: contextRaindropId) { _, newId in
            stella.setContextRaindrop(newId)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Stella")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if stella.sessionState == .ready {
                Menu {
                    Button {
                        stella.newChat()
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
                    }
                    if !stella.chats.isEmpty {
                        Divider()
                        ForEach(stella.chats.prefix(12)) { chat in
                            Button {
                                Task { await stella.openChat(chat.id) }
                            } label: {
                                HStack {
                                    Text(chat.displayTitle)
                                    if chat.id == stella.currentChatId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    if stella.currentChatId != nil {
                        Divider()
                        Button(role: .destructive) {
                            Task { await stella.deleteCurrentChat() }
                        } label: {
                            Label("Delete chat", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .tooltip("Chat history")

                Button {
                    stella.newChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tooltip("New chat")
            }

            Button {
                stella.openInBrowser()
            } label: {
                Image(systemName: "safari")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tooltip("Open Stella in browser")

            Button {
                Task { await stella.checkAccessAndLoad() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tooltip("Retry native Stella")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var subtitle: String {
        if let id = contextRaindropId {
            return "About bookmark · #\(id)"
        }
        switch stella.sessionState {
        case .ready: return stella.statusLine ?? "Native AI · Pro"
        case .checking: return "Connecting…"
        case .notPro: return "Pro required"
        case .needsBrowserFallback: return "Browser fallback"
        }
    }

    // MARK: - States

    private var checkingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Checking Stella access…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notProState: some View {
        EmptyStateView(
            icon: "sparkles",
            title: "Stella needs Pro",
            message: "Your account doesn’t have Stella access. Upgrade on Raindrop.io, then retry.",
            actionTitle: "Open Raindrop",
            action: {
                if let url = URL(string: "https://app.raindrop.io/settings/upgrade") {
                    NSWorkspace.shared.open(url)
                }
            }
        )
    }

    private func browserFallbackState(reason: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.9), Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "safari")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Open Stella in browser")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(reason)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            HStack(spacing: 10) {
                Button {
                    stella.openInBrowser()
                } label: {
                    Label("Open Stella", systemImage: "safari")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Button {
                    Task { await stella.checkAccessAndLoad() }
                } label: {
                    Text("Retry native")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            Text("Same Pro account as this app · full Stella tools in the web app")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Native chat

    private var nativeChat: some View {
        VStack(spacing: 0) {
            if let banner = stella.errorBanner {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(banner)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer()
                    Button("Browser") { stella.openInBrowser() }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    Button {
                        stella.errorBanner = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            messagesList

            Divider().opacity(0.45)

            composer
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if stella.messages.isEmpty {
                        emptyChatHint
                            .padding(.top, 40)
                    } else {
                        ForEach(stella.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }
                }
                .padding(14)
            }
            // Scroll without springs — streaming text updates would thrash CPU with animation
            .onChange(of: stella.messages.last?.text) { _, _ in
                if let id = stella.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: stella.messages.count) { _, _ in
                if let id = stella.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyChatHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.accent.opacity(0.7))
            Text("Ask Stella about your library")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text("Search bookmarks, summarize, or dig into a link — powered by Raindrop AI.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if contextRaindropId != nil {
                Text("This chat is scoped to the selected bookmark.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func messageBubble(_ msg: StellaChatViewModel.DisplayMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 40) }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                Text(msg.text.isEmpty && msg.isStreaming ? "Thinking…" : msg.text)
                    .font(.system(size: 13))
                    .foregroundStyle(msg.isUser ? Color.white : Color.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if let tool = msg.toolNote, !tool.isEmpty {
                    Text(tool)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(msg.isUser ? Color.white.opacity(0.8) : Color.secondary)
                }

                if msg.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(bubbleBackground(isUser: msg.isUser))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(msg.isUser ? Color.clear : Theme.hairline, lineWidth: 1)
            )

            if !msg.isUser { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message Stella…", text: $stella.input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...5)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        stella.send()
                    }
                }

            Button {
                stella.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        stella.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stella.isSending
                            ? Color.secondary.opacity(0.4)
                            : Theme.accent
                    )
            }
            .buttonStyle(PressableButtonStyle(scale: 0.92))
            .disabled(
                stella.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stella.isSending
            )
            .help("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private func bubbleBackground(isUser: Bool) -> some View {
        if isUser {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.subtleFill)
        }
    }
}
