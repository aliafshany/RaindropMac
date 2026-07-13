// StellaChatViewModel.swift
// Native Stella chat via StellaService — browser fallback if OAuth can't access AI API

import Foundation
import AppKit
import Combine

@MainActor
final class StellaChatViewModel: ObservableObject {
    enum SessionState: Equatable {
        case checking
        case ready
        case needsBrowserFallback(String)
        case notPro
    }

    struct DisplayMessage: Identifiable, Equatable {
        let id: String
        let role: String // user | assistant
        var text: String
        var isStreaming: Bool
        var toolNote: String?

        var isUser: Bool { role == "user" }
    }

    @Published var sessionState: SessionState = .checking
    @Published var chats: [StellaChat] = []
    @Published var currentChatId: String?
    @Published var messages: [DisplayMessage] = []
    @Published var input = ""
    @Published var isSending = false
    @Published var statusLine: String?
    @Published var errorBanner: String?

    var contextRaindropId: Int?

    private let service = StellaService.shared
    private var streamTask: Task<Void, Never>?

    static let browserURL = URL(string: "https://beta-ai.raindrop.io/ai")!

    // MARK: - Lifecycle

    func bootstrap(raindropId: Int?) {
        contextRaindropId = raindropId
        Task { await checkAccessAndLoad() }
    }

    func setContextRaindrop(_ id: Int?) {
        contextRaindropId = id
        if id != nil, currentChatId == nil {
            // Hint in empty state only; user starts new chat when they send
            statusLine = "Context: bookmark #\(id!)"
        }
    }

    func checkAccessAndLoad() async {
        sessionState = .checking
        errorBanner = nil
        do {
            let list = try await service.listChats()
            chats = list
            sessionState = .ready
            if let first = list.first {
                await openChat(first.id)
            } else {
                messages = []
                currentChatId = nil
            }
        } catch let err as StellaError {
            switch err {
            case .unauthorized:
                sessionState = .needsBrowserFallback(
                    "Stella’s AI API didn’t accept the app OAuth token. Open Stella in your browser (signed into the same Pro account)."
                )
            case .notPro:
                sessionState = .notPro
            default:
                // Other errors: still try native compose; show banner
                sessionState = .ready
                errorBanner = err.localizedDescription
            }
        } catch {
            sessionState = .needsBrowserFallback(error.localizedDescription)
        }
    }

    // MARK: - Chats

    func openChat(_ id: String) async {
        streamTask?.cancel()
        do {
            let (chat, msgs) = try await service.getChat(id: id)
            currentChatId = chat.id
            messages = msgs.map {
                DisplayMessage(
                    id: $0.id,
                    role: $0.isUser ? "user" : "assistant",
                    text: $0.textContent,
                    isStreaming: false,
                    toolNote: nil
                )
            }
            errorBanner = nil
        } catch {
            handleAPIError(error)
        }
    }

    func newChat() {
        streamTask?.cancel()
        currentChatId = nil
        messages = []
        input = ""
        statusLine = contextRaindropId.map { "New chat · bookmark #\($0)" } ?? "New chat"
        errorBanner = nil
    }

    func deleteCurrentChat() async {
        guard let id = currentChatId else {
            newChat()
            return
        }
        do {
            try await service.deleteChat(id: id)
            chats.removeAll { $0.id == id }
            newChat()
            if let next = chats.first {
                await openChat(next.id)
            }
        } catch {
            handleAPIError(error)
        }
    }

    // MARK: - Send

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        input = ""
        errorBanner = nil
        isSending = true
        statusLine = nil

        let userMsg = DisplayMessage(
            id: UUID().uuidString,
            role: "user",
            text: text,
            isStreaming: false,
            toolNote: nil
        )
        messages.append(userMsg)

        let assistantId = UUID().uuidString
        messages.append(
            DisplayMessage(
                id: assistantId,
                role: "assistant",
                text: "",
                isStreaming: true,
                toolNote: nil
            )
        )

        streamTask?.cancel()
        streamTask = Task {
            defer {
                isSending = false
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].isStreaming = false
                }
            }
            do {
                if let chatId = currentChatId {
                    try await stream(chatId: chatId, message: text, assistantId: assistantId)
                } else {
                    // Create chat with first user message, then stream if needed
                    let (chat, existing) = try await service.createChat(
                        message: text,
                        raindropId: contextRaindropId
                    )
                    currentChatId = chat.id
                    // Refresh chat list
                    if let list = try? await service.listChats() {
                        chats = list
                    } else if !chats.contains(where: { $0.id == chat.id }) {
                        chats.insert(chat, at: 0)
                    }

                    // If create already returned assistant text, use it
                    let assistantText = existing
                        .filter(\.isAssistant)
                        .map(\.textContent)
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !assistantText.isEmpty {
                        if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                            messages[idx].text = assistantText
                            messages[idx].isStreaming = false
                        }
                    } else {
                        // Continue/regenerate stream for assistant reply
                        try await stream(chatId: chat.id, message: nil, assistantId: assistantId)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                // Remove empty streaming bubble
                if let idx = messages.firstIndex(where: { $0.id == assistantId }),
                   messages[idx].text.isEmpty {
                    messages.remove(at: idx)
                }
                handleAPIError(error)
            }
        }
    }

    private func stream(chatId: String, message: String?, assistantId: String) async throws {
        for try await event in service.streamMessage(
            chatId: chatId,
            message: message,
            raindropId: contextRaindropId
        ) {
            if Task.isCancelled { break }
            switch event {
            case .textDelta(let delta):
                // Batch small deltas: still append immediately but avoid extra allocations
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].text.append(contentsOf: delta)
                }
            case .tool(let name):
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].toolNote = "Using \(name)…"
                }
                statusLine = "Stella · \(name)"
            case .toolFinished:
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].toolNote = nil
                }
                statusLine = nil
            case .finished(let msg, let tools):
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    if messages[idx].text.isEmpty, !msg.textContent.isEmpty {
                        messages[idx].text = msg.textContent
                    }
                    messages[idx].isStreaming = false
                    if !tools.isEmpty {
                        messages[idx].toolNote = tools.joined(separator: ", ")
                    }
                }
                statusLine = nil
            }
        }
    }

    // MARK: - Fallback

    func openInBrowser() {
        var components = URLComponents(url: Self.browserURL, resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let contextRaindropId {
            items.append(URLQueryItem(name: "raindropId", value: "\(contextRaindropId)"))
        }
        components.queryItems = items.isEmpty ? nil : items
        NSWorkspace.shared.open(components.url ?? Self.browserURL)
    }

    private func handleAPIError(_ error: Error) {
        if let e = error as? StellaError {
            switch e {
            case .unauthorized:
                sessionState = .needsBrowserFallback(
                    "Native Stella couldn’t authenticate with your OAuth token. Use the browser version for full Stella."
                )
            case .notPro:
                sessionState = .notPro
            default:
                errorBanner = e.localizedDescription
            }
        } else {
            errorBanner = error.localizedDescription
        }
    }
}
