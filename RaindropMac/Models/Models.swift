// Models.swift
// Raindrop.io data models

import Foundation
import SwiftUI

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
        case email, name, avatar, pro
    }
}

struct UserResponse: Codable {
    let user: User
}

// MARK: - System stats
struct UserStatsResponse: Codable {
    let items: [StatItem]
    let result: Bool
}

struct StatItem: Codable, Identifiable {
    let id: Int
    let count: Int
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case count
    }
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
    let view: String?
    let isPublic: Bool?
    let cover: [String]?
    let expanded: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, color, count, access, parent, sort, view
        case isPublic = "public"
        case cover, expanded
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RaindropCollection, rhs: RaindropCollection) -> Bool { lhs.id == rhs.id }

    var displayColor: Color {
        Theme.color(fromHex: color) ?? Theme.accent
    }
}

struct CollectionAccess: Codable {
    let level: Int?
    let draggable: Bool?
}

struct CollectionsResponse: Codable {
    let items: [RaindropCollection]
    let result: Bool
}

struct CollectionItemResponse: Codable {
    let item: RaindropCollection
    let result: Bool
}

// MARK: - Raindrop
struct RaindropCache: Codable, Hashable {
    let status: String?
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
    let note: String?
    let cache: RaindropCache?
    let highlights: [RaindropHighlight]?
    let media: [RaindropMedia]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, link, excerpt, cover, tags, type, created, lastUpdate
        case important, collection, domain, note, cache, highlights, media
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Raindrop, rhs: Raindrop) -> Bool { lhs.id == rhs.id }

    var displayTitle: String {
        title.isEmpty ? (domain ?? link) : title
    }

    var displayDomain: String {
        domain ?? URL(string: link)?.host ?? link
    }

    var typeIcon: String {
        switch type {
        case "image": return "photo"
        case "video": return "play.rectangle.fill"
        case "article": return "doc.richtext"
        case "audio": return "music.note"
        case "document": return "doc.fill"
        default: return "link"
        }
    }

    var typeColor: Color {
        switch type {
        case "image": return .pink
        case "video": return .red
        case "article": return .blue
        case "audio": return .purple
        case "document": return .orange
        default: return Theme.accent
        }
    }

    func with(
        important: Bool? = nil,
        title: String? = nil,
        tags: [String]? = nil,
        note: String? = nil,
        excerpt: String? = nil,
        collection: RaindropCollectionRef? = nil
    ) -> Raindrop {
        Raindrop(
            id: id,
            title: title ?? self.title,
            link: link,
            excerpt: excerpt ?? self.excerpt,
            cover: cover,
            tags: tags ?? self.tags,
            type: type,
            created: created,
            lastUpdate: lastUpdate,
            important: important ?? self.important,
            collection: collection ?? self.collection,
            domain: domain,
            note: note ?? self.note,
            cache: cache,
            highlights: highlights,
            media: media
        )
    }
}

struct RaindropMedia: Codable, Hashable {
    let link: String?
    let type: String?
}

struct RaindropCollectionRef: Codable, Hashable {
    let id: Int?
    enum CodingKeys: String, CodingKey { case id = "$id" }
}

struct RaindropsResponse: Codable {
    let items: [Raindrop]
    let count: Int
    let result: Bool
}

struct CreateRaindropResponse: Codable {
    let item: Raindrop
    let result: Bool
}

struct DeleteResponse: Codable {
    let result: Bool
    let modified: Int?
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

// MARK: - Filters
struct FiltersResponse: Codable {
    let result: Bool
    let broken: FilterCount?
    let duplicates: FilterCount?
    let important: FilterCount?
    let notag: FilterCount?
    let tags: [RaindropTag]?
    let types: [TypeFilter]?
}

struct FilterCount: Codable {
    let count: Int
}

struct TypeFilter: Codable, Identifiable, Hashable {
    let type: String
    let count: Int
    var id: String { type }
    enum CodingKeys: String, CodingKey {
        case type = "_id"
        case count
    }

    var icon: String {
        switch type {
        case "image": return "photo"
        case "video": return "play.rectangle.fill"
        case "article": return "doc.richtext"
        case "audio": return "music.note"
        case "document": return "doc.fill"
        default: return "link"
        }
    }

    var label: String { type.capitalized }
}

// MARK: - Suggest
struct SuggestResponse: Codable {
    let result: Bool
    let item: SuggestItem
}

struct SuggestItem: Codable {
    let collections: [RaindropCollectionRef]?
    let tags: [String]?
}

// MARK: - App enums
enum ViewMode: String, CaseIterable, Identifiable {
    case list, headlines, grid, masonry
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .headlines: return "text.justify.left"
        case .grid: return "square.grid.2x2"
        case .masonry: return "rectangle.3.group"
        }
    }

    var label: String {
        switch self {
        case .list: return "List"
        case .headlines: return "Headlines"
        case .grid: return "Grid"
        case .masonry: return "Masonry"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case newest = "-created"
    case oldest = "created"
    case titleAsc = "title"
    case titleDesc = "-title"
    case domainAsc = "domain"
    case domainDesc = "-domain"
    case manual = "-sort"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        case .titleAsc: return "Title A–Z"
        case .titleDesc: return "Title Z–A"
        case .domainAsc: return "Domain A–Z"
        case .domainDesc: return "Domain Z–A"
        case .manual: return "Manual order"
        }
    }

    var icon: String {
        switch self {
        case .newest, .oldest: return "calendar"
        case .titleAsc, .titleDesc: return "textformat"
        case .domainAsc, .domainDesc: return "globe"
        case .manual: return "arrow.up.arrow.down"
        }
    }
}

enum SystemCollection: Int, CaseIterable, Identifiable {
    case all = 0
    case unsorted = -1
    case trash = -99
    case favorites = -10
    case stella = -2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: return "All Bookmarks"
        case .unsorted: return "Unsorted"
        case .trash: return "Trash"
        case .favorites: return "Favorites"
        case .stella: return "Ask Stella"
        }
    }

    var icon: String {
        switch self {
        case .all: return "bookmark.fill"
        case .unsorted: return "tray.fill"
        case .trash: return "trash.fill"
        case .favorites: return "star.fill"
        case .stella: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .all: return Theme.accent
        case .unsorted: return .gray
        case .trash: return .red.opacity(0.8)
        case .favorites: return .yellow
        case .stella: return .purple
        }
    }

    /// API collection id used for fetching (favorites uses search)
    var apiCollectionId: Int {
        switch self {
        case .favorites: return 0
        default: return rawValue
        }
    }
}
