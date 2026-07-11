// APIService.swift
// Raindrop.io REST API client

import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case invalidURL
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Not authenticated. Please sign in."
        case .invalidURL: return "Invalid URL."
        case .decodingError(let msg): return "Data error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
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

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // Debug: print raw response
        if let raw = String(data: data, encoding: .utf8) {
            print("API [\(path)] response: \(String(raw.prefix(500)))")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            // Print detailed decoding error
            switch decodingError {
            case .keyNotFound(let key, let ctx):
                print("DECODE ERROR: Missing key '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue))")
            case .typeMismatch(let type, let ctx):
                print("DECODE ERROR: Type mismatch for \(type) at \(ctx.codingPath.map(\.stringValue))")
            case .valueNotFound(let type, let ctx):
                print("DECODE ERROR: Value not found for \(type) at \(ctx.codingPath.map(\.stringValue))")
            case .dataCorrupted(let ctx):
                print("DECODE ERROR: Data corrupted at \(ctx.codingPath.map(\.stringValue))")
            @unknown default:
                print("DECODE ERROR: \(decodingError)")
            }
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

    // MARK: - Collections
    func fetchCollections() async throws -> [RaindropCollection] {
        let response: CollectionsResponse = try await fetch("/collections")
        let children: CollectionsResponse = try await fetch("/collections/childrens")
        return response.items + children.items
    }

    // MARK: - Raindrops
    func fetchRaindrops(collectionId: Int, page: Int = 0, perPage: Int = 25) async throws -> RaindropsResponse {
        return try await fetch("/raindrops/\(collectionId)?page=\(page)&perpage=\(perPage)")
    }

    func fetchAllRaindrops(page: Int = 0) async throws -> RaindropsResponse {
        return try await fetch("/raindrops/0?page=\(page)&perpage=25")
    }

    // MARK: - Search
    func searchRaindrops(query: String, collectionId: Int = 0) async throws -> RaindropsResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await fetch("/raindrops/\(collectionId)?search=\(encoded)&perpage=25")
    }

    // MARK: - Tags
    func fetchTags(collectionId: Int = 0) async throws -> [RaindropTag] {
        let response: TagsResponse = try await fetch("/tags/\(collectionId)")
        return response.items
    }

    // MARK: - Create Raindrop
    func createRaindrop(link: String, title: String?, collectionId: Int, tags: [String]) async throws -> Raindrop {
        var body: [String: Any] = [
            "link": link,
            "collectionId": collectionId,
            "tags": tags
        ]
        if let title = title { body["title"] = title }

        let data = try JSONSerialization.data(withJSONObject: body)
        let response: CreateRaindropResponse = try await fetch("/raindrop", method: "POST", body: data)
        return response.item
    }

    // MARK: - Update Raindrop
    func updateRaindrop(id: Int, link: String, title: String?, collectionId: Int, tags: [String]) async throws -> Raindrop {
        var body: [String: Any] = [
            "link": link,
            "collectionId": collectionId,
            "tags": tags
        ]
        if let title = title { body["title"] = title }
        
        let data = try JSONSerialization.data(withJSONObject: body)
        let response: CreateRaindropResponse = try await fetch("/raindrop/\(id)", method: "PUT", body: data)
        return response.item
    }

    // MARK: - Delete Raindrop
    func deleteRaindrop(id: Int) async throws {
        let _: DeleteResponse = try await fetch("/raindrop/\(id)", method: "DELETE")
    }

    // MARK: - Favorite
    func toggleFavorite(id: Int, important: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["important": important])
        let _: CreateRaindropResponse = try await fetch("/raindrop/\(id)", method: "PUT", body: body)
    }
}

struct CreateRaindropResponse: Codable {
    let item: Raindrop
    let result: Bool
}

struct DeleteResponse: Codable {
    let result: Bool
}
