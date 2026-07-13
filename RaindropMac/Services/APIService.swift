// APIService.swift
// Raindrop.io REST API client

import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case invalidURL
    case decodingError(String)
    case networkError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Not authenticated. Please sign in."
        case .invalidURL: return "Invalid URL."
        case .decodingError(let msg): return "Data error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .serverError(let msg): return msg
        }
    }
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://api.raindrop.io/rest/v1"

    private var token: String? { AuthService.shared.accessToken }

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let token = token else { throw APIError.unauthorized }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func fetch<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        let request = try makeRequest(path, method: method, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            if httpResponse.statusCode == 429 {
                throw APIError.serverError("Rate limit exceeded. Please wait a moment.")
            }
            if httpResponse.statusCode >= 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["errorMessage"] as? String {
                    throw APIError.serverError(msg)
                }
                throw APIError.serverError("Request failed (\(httpResponse.statusCode))")
            }
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            #if DEBUG
            switch decodingError {
            case .keyNotFound(let key, let ctx):
                print("DECODE: Missing key '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue))")
            case .typeMismatch(let type, let ctx):
                print("DECODE: Type mismatch \(type) at \(ctx.codingPath.map(\.stringValue))")
            case .valueNotFound(let type, let ctx):
                print("DECODE: Value not found \(type) at \(ctx.codingPath.map(\.stringValue))")
            case .dataCorrupted(let ctx):
                print("DECODE: Corrupted at \(ctx.codingPath.map(\.stringValue))")
            @unknown default:
                print("DECODE: \(decodingError)")
            }
            #endif
            throw APIError.decodingError(decodingError.localizedDescription)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - User
    func fetchUser() async throws -> User {
        let response: UserResponse = try await fetch("/user")
        return response.user
    }

    func fetchStats() async throws -> [StatItem] {
        let response: UserStatsResponse = try await fetch("/user/stats")
        return response.items
    }

    // MARK: - Collections
    func fetchCollections() async throws -> [RaindropCollection] {
        let response: CollectionsResponse = try await fetch("/collections")
        let children: CollectionsResponse = try await fetch("/collections/childrens")
        return response.items + children.items
    }

    func createCollection(title: String, parentId: Int? = nil, isPublic: Bool = false, view: String = "list") async throws -> RaindropCollection {
        var body: [String: Any] = [
            "title": title,
            "public": isPublic,
            "view": view
        ]
        if let parentId {
            body["parent"] = ["$id": parentId]
        }
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: CollectionItemResponse = try await fetch("/collection", method: "POST", body: data)
        return response.item
    }

    func updateCollection(id: Int, title: String? = nil, isPublic: Bool? = nil, view: String? = nil, parentId: Int? = nil) async throws -> RaindropCollection {
        var body: [String: Any] = [:]
        if let title { body["title"] = title }
        if let isPublic { body["public"] = isPublic }
        if let view { body["view"] = view }
        if let parentId { body["parent"] = ["$id": parentId] }
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: CollectionItemResponse = try await fetch("/collection/\(id)", method: "PUT", body: data)
        return response.item
    }

    func deleteCollection(id: Int) async throws {
        let _: DeleteResponse = try await fetch("/collection/\(id)", method: "DELETE")
    }

    func emptyTrash() async throws {
        let _: DeleteResponse = try await fetch("/collection/-99", method: "DELETE")
    }

    // MARK: - Raindrops
    func fetchRaindrops(
        collectionId: Int,
        page: Int = 0,
        perPage: Int = 40,
        sort: String = "-created",
        search: String? = nil,
        nested: Bool = true
    ) async throws -> RaindropsResponse {
        var query: [String] = [
            "page=\(page)",
            "perpage=\(min(perPage, 50))",
            "sort=\(sort.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sort)",
            "nested=\(nested ? "true" : "false")"
        ]
        if let search, !search.isEmpty {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            query.append("search=\(encoded)")
        }
        return try await fetch("/raindrops/\(collectionId)?\(query.joined(separator: "&"))")
    }

    func getRaindrop(id: Int) async throws -> Raindrop {
        let response: CreateRaindropResponse = try await fetch("/raindrop/\(id)")
        return response.item
    }

    func createRaindrop(
        link: String,
        title: String? = nil,
        collectionId: Int = -1,
        tags: [String] = [],
        note: String? = nil,
        excerpt: String? = nil,
        important: Bool = false,
        pleaseParse: Bool = true
    ) async throws -> Raindrop {
        var body: [String: Any] = [
            "link": link,
            "collection": ["$id": collectionId],
            "tags": tags,
            "important": important
        ]
        if let title, !title.isEmpty { body["title"] = title }
        if let note, !note.isEmpty { body["note"] = note }
        if let excerpt, !excerpt.isEmpty { body["excerpt"] = excerpt }
        if pleaseParse { body["pleaseParse"] = [:] }

        let data = try JSONSerialization.data(withJSONObject: body)
        let response: CreateRaindropResponse = try await fetch("/raindrop", method: "POST", body: data)
        return response.item
    }

    func updateRaindrop(
        id: Int,
        link: String? = nil,
        title: String? = nil,
        collectionId: Int? = nil,
        tags: [String]? = nil,
        note: String? = nil,
        excerpt: String? = nil,
        important: Bool? = nil,
        pleaseParse: Bool = false
    ) async throws -> Raindrop {
        var body: [String: Any] = [:]
        if let link { body["link"] = link }
        if let title { body["title"] = title }
        if let collectionId { body["collection"] = ["$id": collectionId] }
        if let tags { body["tags"] = tags }
        if let note { body["note"] = note }
        if let excerpt { body["excerpt"] = excerpt }
        if let important { body["important"] = important }
        if pleaseParse { body["pleaseParse"] = [:] }

        let data = try JSONSerialization.data(withJSONObject: body)
        let response: CreateRaindropResponse = try await fetch("/raindrop/\(id)", method: "PUT", body: data)
        return response.item
    }

    func deleteRaindrop(id: Int) async throws {
        let _: DeleteResponse = try await fetch("/raindrop/\(id)", method: "DELETE")
    }

    func toggleFavorite(id: Int, important: Bool) async throws -> Raindrop {
        try await updateRaindrop(id: id, important: important)
    }

    func moveRaindrop(id: Int, toCollectionId: Int) async throws -> Raindrop {
        try await updateRaindrop(id: id, collectionId: toCollectionId)
    }

    // MARK: - Suggest
    func suggest(for link: String) async throws -> SuggestItem {
        let data = try JSONSerialization.data(withJSONObject: ["link": link])
        let response: SuggestResponse = try await fetch("/raindrop/suggest", method: "POST", body: data)
        return response.item
    }

    // MARK: - Tags
    func fetchTags(collectionId: Int = 0) async throws -> [RaindropTag] {
        let response: TagsResponse = try await fetch("/tags/\(collectionId)")
        return response.items.sorted { $0.count > $1.count }
    }

    func renameTag(old: String, new: String, collectionId: Int = 0) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "replace": new,
            "tags": [old]
        ])
        let _: DeleteResponse = try await fetch("/tags/\(collectionId)", method: "PUT", body: body)
    }

    func deleteTags(_ tags: [String], collectionId: Int = 0) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["tags": tags])
        var request = try makeRequest("/tags/\(collectionId)", method: "DELETE", body: body)
        // DELETE with body
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.unauthorized
        }
        _ = data
    }

    // MARK: - Filters
    func fetchFilters(collectionId: Int = 0, search: String? = nil) async throws -> FiltersResponse {
        var path = "/filters/\(collectionId)"
        if let search, !search.isEmpty {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            path += "?search=\(encoded)"
        }
        return try await fetch(path)
    }

    // MARK: - Bulk raindrops
    /// Bulk update selected raindrops (move / favorite / tags merge).
    func bulkUpdateRaindrops(
        ids: [Int],
        collectionId: Int? = nil,
        important: Bool? = nil,
        tags: [String]? = nil,
        nested: Bool = true
    ) async throws {
        guard !ids.isEmpty else { return }
        var body: [String: Any] = ["ids": ids]
        if let collectionId { body["collection"] = ["$id": collectionId] }
        if let important { body["important"] = important }
        if let tags { body["tags"] = tags }
        let data = try JSONSerialization.data(withJSONObject: body)
        // Target "all" collection endpoint for bulk ops
        let _: DeleteResponse = try await fetch("/raindrops/0?nested=\(nested)", method: "PUT", body: data)
    }

    func bulkDeleteRaindrops(ids: [Int]) async throws {
        guard !ids.isEmpty else { return }
        let data = try JSONSerialization.data(withJSONObject: ["ids": ids])
        let _: DeleteResponse = try await fetch("/raindrops/0", method: "DELETE", body: data)
    }

    /// Fetch all raindrops for export (paginated).
    func fetchAllRaindrops(collectionId: Int = 0, search: String? = nil) async throws -> [Raindrop] {
        var page = 0
        var all: [Raindrop] = []
        while true {
            let resp = try await fetchRaindrops(
                collectionId: collectionId,
                page: page,
                perPage: 50,
                sort: "-created",
                search: search,
                nested: true
            )
            all.append(contentsOf: resp.items)
            if all.count >= resp.count || resp.items.isEmpty { break }
            page += 1
            if page > 200 { break } // safety
        }
        return all
    }
}
