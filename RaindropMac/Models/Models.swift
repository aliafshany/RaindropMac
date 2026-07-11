// Models.swift
// Raindrop.io data models

import Foundation

// MARK: - Auth
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - User
struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let name: String
    let avatar: String?
    let pro: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, name, avatar = "avatar", pro
    }
}

struct UserResponse: Codable {
    let user: User
}

// MARK: - Collection
struct RaindropCollection: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let color: String?
    let count: Int
    let access: CollectionAccess?
    let parent: RaindropCollectionRef?
    let sort: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, color, count, access
        case parent
        case sort
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RaindropCollection, rhs: RaindropCollection) -> Bool { lhs.id == rhs.id }
}

struct CollectionAccess: Codable {
    let level: Int
    let draggable: Bool
}

struct CollectionsResponse: Codable {
    let items: [RaindropCollection]
    let result: Bool
}

struct RaindropCache: Codable, Hashable {
    let status: String
    let size: Int?
    let created: String?
}

struct RaindropHighlight: Codable, Identifiable, Hashable {
    let _id: String
    let text: String
    let color: String?
    let note: String?
    let created: String?
    var id: String { _id }
}

struct Raindrop: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let link: String
    let excerpt: String?
    let cover: String?
    let tags: [String]?
    let type: String?
    let created: String?
    let lastUpdate: String?
    let important: Bool?
    let collection: RaindropCollectionRef?
    let domain: String?
    
    // Pro Features
    let note: String?
    let cache: RaindropCache?
    let highlights: [RaindropHighlight]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, link, excerpt, cover, tags, type, created, lastUpdate, important, collection, domain
        case note, cache, highlights
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Raindrop, rhs: Raindrop) -> Bool { lhs.id == rhs.id }
}

struct RaindropCollectionRef: Codable {
    let id: Int?
    enum CodingKeys: String, CodingKey { case id = "$id" }
}

struct RaindropsResponse: Codable {
    let items: [Raindrop]
    let count: Int
    let result: Bool
}

// MARK: - Tag
struct RaindropTag: Codable, Identifiable, Hashable {
    let tag: String
    let count: Int
    var id: String { tag }
    
    enum CodingKeys: String, CodingKey {
        case tag = "_id"
        case count
    }
}

struct TagsResponse: Codable {
    let items: [RaindropTag]
    let result: Bool
}

// MARK: - Search
struct SearchResult: Codable {
    let items: [Raindrop]
    let count: Int
    let result: Bool
}
