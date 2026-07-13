// StellaService.swift
// Raindrop Stella AI (v2) client with streaming

import Foundation

// MARK: - Models

struct StellaChat: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let created: String?
    let lastUpdate: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, created, lastUpdate
    }

    var displayTitle: String {
        let t = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "New chat" : t
    }
}

struct StellaMessagePart: Codable, Hashable {
    let type: String
    let text: String?
    let data: StellaJSONValue?
    let toolCallId: String?
    let toolName: String?
    let input: StellaJSONValue?
    let output: StellaJSONValue?
    let state: String?

    enum CodingKeys: String, CodingKey {
        case type, text, data, toolCallId, toolName, input, output, state
    }

    init(type: String, text: String? = nil, data: StellaJSONValue? = nil,
         toolCallId: String? = nil, toolName: String? = nil,
         input: StellaJSONValue? = nil, output: StellaJSONValue? = nil, state: String? = nil) {
        self.type = type
        self.text = text
        self.data = data
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.input = input
        self.output = output
        self.state = state
    }
}

/// Lightweight JSON value for flexible AI payloads
enum StellaJSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: StellaJSONValue])
    case array([StellaJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: StellaJSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([StellaJSONValue].self) { self = .array(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .number(let n) = self { return Int(n) }
        if case .string(let s) = self { return Int(s) }
        return nil
    }
}

struct StellaMessage: Codable, Identifiable, Hashable {
    var id: String
    var role: String
    var parts: [StellaMessagePart]

    var textContent: String {
        parts
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" || role == "ai" }

    /// Raindrop IDs mentioned in tool results / data parts
    var linkedRaindropIds: [Int] {
        var ids: [Int] = []
        for part in parts {
            if part.type.hasPrefix("data-"), let data = part.data {
                collectIds(from: data, into: &ids)
            }
            if let out = part.output {
                collectIds(from: out, into: &ids)
            }
            if let input = part.input {
                collectIds(from: input, into: &ids)
            }
        }
        return Array(Set(ids))
    }

    private func collectIds(from value: StellaJSONValue, into ids: inout [Int]) {
        switch value {
        case .number(let n):
            let i = Int(n)
            if i > 0 { ids.append(i) }
        case .object(let obj):
            if let id = obj["_id"]?.intValue ?? obj["id"]?.intValue ?? obj["raindropId"]?.intValue {
                if id > 0 { ids.append(id) }
            }
            for v in obj.values { collectIds(from: v, into: &ids) }
        case .array(let arr):
            for v in arr { collectIds(from: v, into: &ids) }
        default: break
        }
    }
}

// MARK: - Service

enum StellaError: Error, LocalizedError {
    case unauthorized
    case notPro
    case network(String)
    case decoding(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Not authenticated."
        case .notPro: return "Stella is available on Raindrop Pro."
        case .network(let m): return m
        case .decoding(let m): return m
        case .emptyResponse: return "No response from Stella."
        }
    }
}

final class StellaService {
    static let shared = StellaService()
    /// Matches the web Stella client (not /rest/v1).
    private let baseURL = "https://api.raindrop.io/v2"

    private var token: String? { AuthService.shared.accessToken }

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let token, !token.isEmpty else { throw StellaError.unauthorized }
        guard let url = URL(string: baseURL + path) else { throw StellaError.network("Invalid URL") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        // Web Stella uses session cookies; OAuth clients use Bearer. Send both.
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("token=\(token)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://app.raindrop.io", forHTTPHeaderField: "Origin")
        request.setValue("https://app.raindrop.io/", forHTTPHeaderField: "Referer")
        request.httpBody = body
        return request
    }

    // MARK: Chats list
    func listChats() async throws -> [StellaChat] {
        let request = try makeRequest("/ai/chats")
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data: data)

        // Flexible decode
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let items = (json["items"] as? [[String: Any]]) ?? []
            return items.compactMap { dict -> StellaChat? in
                guard let id = stringId(dict["_id"]) else { return nil }
                return StellaChat(
                    id: id,
                    title: dict["title"] as? String,
                    created: dict["created"] as? String,
                    lastUpdate: dict["lastUpdate"] as? String
                )
            }
        }
        return []
    }

    // MARK: Create chat
    func createChat(message: String, raindropId: Int? = nil) async throws -> (chat: StellaChat, messages: [StellaMessage]) {
        var parts: [[String: Any]] = [["type": "text", "text": message]]
        if let raindropId {
            parts.append(["type": "data-raindropId", "data": raindropId])
        }
        let body: [String: Any] = [
            "messages": [
                [
                    "id": "",
                    "role": "user",
                    "parts": parts
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try makeRequest("/ai/chat", method: "POST", body: data)
        let (respData, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data: respData)

        let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] ?? [:]
        guard let item = json["item"] as? [String: Any],
              let id = stringId(item["_id"]) else {
            throw StellaError.decoding("Could not create chat")
        }
        let chat = StellaChat(
            id: id,
            title: item["title"] as? String,
            created: item["created"] as? String,
            lastUpdate: item["lastUpdate"] as? String
        )
        let messages = parseMessages(json["messages"])
        return (chat, messages)
    }

    // MARK: Load chat
    func getChat(id: String) async throws -> (chat: StellaChat, messages: [StellaMessage]) {
        let request = try makeRequest("/ai/chat/\(id)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data: data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let item = json["item"] as? [String: Any],
              let chatId = stringId(item["_id"]) else {
            throw StellaError.decoding("Invalid chat")
        }
        let chat = StellaChat(
            id: chatId,
            title: item["title"] as? String,
            created: item["created"] as? String,
            lastUpdate: item["lastUpdate"] as? String
        )
        return (chat, parseMessages(json["messages"]))
    }

    // MARK: Delete
    func deleteChat(id: String) async throws {
        let request = try makeRequest("/ai/chat/\(id)", method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data: data)
    }

    // MARK: Stream reply
    /// Streams Stella’s reply. Pass `message` for a new user turn; omit for continue/regenerate after create.
    func streamMessage(
        chatId: String,
        message: String? = nil,
        raindropId: Int? = nil
    ) -> AsyncThrowingStream<StellaStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body: [String: Any]
                    if let message, !message.isEmpty {
                        var parts: [[String: Any]] = [["type": "text", "text": message]]
                        if let raindropId {
                            parts.append(["type": "data-raindropId", "data": raindropId])
                        }
                        body = [
                            "messages": [
                                [
                                    "id": UUID().uuidString,
                                    "role": "user",
                                    "parts": parts
                                ]
                            ]
                        ]
                    } else {
                        // regenerate / continue after chat create
                        body = [:]
                    }
                    let data = try JSONSerialization.data(withJSONObject: body)
                    var request = try makeRequest("/ai/chat/\(chatId)", method: "POST", body: data)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse {
                        if http.statusCode == 401 { throw StellaError.unauthorized }
                        if http.statusCode == 403 { throw StellaError.notPro }
                        if http.statusCode >= 400 {
                            throw StellaError.network("Stella error (\(http.statusCode))")
                        }
                    }

                    var assembled = ""
                    var toolNotes: [String] = []
                    var buffer = ""

                    for try await byteLine in bytes.lines {
                        let line = byteLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        if line.isEmpty { continue }

                        // SSE: "data: {...}" or raw JSON lines
                        var payload = line
                        if payload.hasPrefix("data:") {
                            payload = String(payload.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        }
                        if payload == "[DONE]" {
                            break
                        }

                        // Some servers send multi-line JSON; try parse single line first
                        buffer = payload
                        guard let chunkData = buffer.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any],
                              let type = obj["type"] as? String else {
                            continue
                        }

                        switch type {
                        case "text-delta":
                            if let delta = obj["delta"] as? String {
                                assembled += delta
                                continuation.yield(.textDelta(delta))
                            }
                        case "text-start", "text-end":
                            break
                        case "error":
                            let msg = (obj["errorText"] as? String) ?? "Stella error"
                            throw StellaError.network(msg)
                        case "tool-input-start", "tool-input-available":
                            if let name = obj["toolName"] as? String {
                                toolNotes.append(name)
                                continuation.yield(.tool(name))
                            }
                        case "tool-output-available":
                            continuation.yield(.toolFinished)
                        case "finish", "message-metadata", "start", "start-step", "finish-step", "abort":
                            break
                        default:
                            // data-* or other — ignore for stream text
                            break
                        }
                    }

                    let assistant = StellaMessage(
                        id: UUID().uuidString,
                        role: "assistant",
                        parts: [StellaMessagePart(type: "text", text: assembled)]
                    )
                    continuation.yield(.finished(assistant, toolNotes: toolNotes))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: Helpers

    private func throwIfNeeded(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw StellaError.unauthorized }
        if http.statusCode == 403 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String {
                throw StellaError.network(err)
            }
            throw StellaError.notPro
        }
        if http.statusCode == 429 {
            throw StellaError.network("Stella is busy — try again in a moment.")
        }
        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String ?? json["errorMessage"] as? String {
                throw StellaError.network(err)
            }
            throw StellaError.network("Request failed (\(http.statusCode))")
        }
    }

    private func stringId(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let i = value as? Int { return String(i) }
        if let i = value as? Int64 { return String(i) }
        return nil
    }

    private func parseMessages(_ raw: Any?) -> [StellaMessage] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { dict -> StellaMessage? in
            guard let id = stringId(dict["id"]) ?? stringId(dict["_id"]) else {
                return StellaMessage(
                    id: UUID().uuidString,
                    role: dict["role"] as? String ?? "assistant",
                    parts: parseParts(dict["parts"])
                )
            }
            return StellaMessage(
                id: id,
                role: dict["role"] as? String ?? "assistant",
                parts: parseParts(dict["parts"])
            )
        }
    }

    private func parseParts(_ raw: Any?) -> [StellaMessagePart] {
        guard let arr = raw as? [[String: Any]] else {
            // Sometimes message is just content string
            if let s = raw as? String {
                return [StellaMessagePart(type: "text", text: s)]
            }
            return []
        }
        return arr.map { dict in
            StellaMessagePart(
                type: dict["type"] as? String ?? "text",
                text: dict["text"] as? String,
                data: decodeJSONValue(dict["data"]),
                toolCallId: dict["toolCallId"] as? String,
                toolName: dict["toolName"] as? String,
                input: decodeJSONValue(dict["input"]),
                output: decodeJSONValue(dict["output"]),
                state: dict["state"] as? String
            )
        }
    }

    private func decodeJSONValue(_ any: Any?) -> StellaJSONValue? {
        guard let any else { return nil }
        if any is NSNull { return .null }
        if let s = any as? String { return .string(s) }
        if let b = any as? Bool { return .bool(b) }
        if let n = any as? NSNumber {
            // Distinguish bool boxed as NSNumber
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return .bool(n.boolValue)
            }
            return .number(n.doubleValue)
        }
        if let d = any as? [String: Any] {
            var obj: [String: StellaJSONValue] = [:]
            for (k, v) in d {
                obj[k] = decodeJSONValue(v) ?? .null
            }
            return .object(obj)
        }
        if let a = any as? [Any] {
            return .array(a.map { decodeJSONValue($0) ?? .null })
        }
        return nil
    }
}

enum StellaStreamEvent {
    case textDelta(String)
    case tool(String)
    case toolFinished
    case finished(StellaMessage, toolNotes: [String])
}
