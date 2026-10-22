import Foundation

// Supabase table and view models that can be decoded outside the main thread.

nonisolated struct SpecRow: Codable, Sendable {
    let label: String
    let value: String
}

nonisolated struct ProductRow: Decodable, Sendable {
    let id: UUID
    let slug: String
    let name: String
    let brand: String
    let category: String
    let memoryGb: Int?
    let storageGb: Int?
    let keySpec: String?
    let tagline: String?
    let imageUrl: String?
    let specs: [SpecRow]
    let barcodes: [String]

    enum CodingKeys: String, CodingKey {
        case id, slug, name, brand, category, tagline, specs, barcodes
        case memoryGb = "memory_gb"
        case storageGb = "storage_gb"
        case keySpec = "key_spec"
        case imageUrl = "image_url"
    }
}

nonisolated struct OfferRow: Decodable, Sendable {
    let productId: UUID
    let retailerId: String
    let title: String
    let url: String
    let sku: String?
    let price: Double
    let originalPrice: Double?
    let inStock: Bool
    let isPreorder: Bool

    enum CodingKeys: String, CodingKey {
        case title, url, sku, price
        case productId = "product_id"
        case retailerId = "retailer_id"
        case originalPrice = "original_price"
        case inStock = "in_stock"
        case isPreorder = "is_preorder"
    }
}

nonisolated struct ListingTitleRow: Decodable, Sendable {
    let productId: UUID
    let retailerId: String
    let title: String

    enum CodingKeys: String, CodingKey {
        case title
        case productId = "product_id"
        case retailerId = "retailer_id"
    }
}

nonisolated struct PriceHistoryRow: Decodable, Sendable {
    let productId: UUID
    let day: Date
    let price: Double

    enum CodingKeys: String, CodingKey {
        case day, price
        case productId = "product_id"
    }
}

nonisolated struct StoreBranchRecord: Decodable, Sendable {
    let id: UUID
    let retailerId: String
    let name: String
    let storeType: String?
    let address: String?
    let city: String?
    let latitude: Double
    let longitude: Double
    let openingHours: String?

    enum CodingKeys: String, CodingKey {
        case id, name, address, city, latitude, longitude
        case retailerId = "retailer_id"
        case storeType = "store_type"
        case openingHours = "opening_hours"
    }
}

nonisolated struct ProfileRow: Codable, Sendable {
    var fullName: String?
    var avatarUrl: String?
    var signInMethod: String
    var appearanceMode: String
    var shoppingPriority: String
    var faceIdEnabled: Bool
    var notifyPriceDrops: Bool
    var notifyTracking: Bool
    var notifyInsights: Bool

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case signInMethod = "sign_in_method"
        case appearanceMode = "appearance_mode"
        case shoppingPriority = "shopping_priority"
        case faceIdEnabled = "face_id_enabled"
        case notifyPriceDrops = "notify_price_drops"
        case notifyTracking = "notify_tracking"
        case notifyInsights = "notify_insights"
    }
}

nonisolated struct TrackedRow: Codable, Sendable {
    let productId: UUID
    var previousPrice: Double
    var alertsEnabled: Bool
    var dropThresholdPercent: Double
    var trackedAt: Date?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case previousPrice = "previous_price"
        case alertsEnabled = "alerts_enabled"
        case dropThresholdPercent = "drop_threshold_percent"
        case trackedAt = "tracked_at"
    }
}

nonisolated struct ProductRefRow: Codable, Sendable {
    let productId: UUID

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
    }
}

nonisolated struct RecentlyViewedRow: Codable, Sendable {
    let productId: UUID
    let viewedAt: Date

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case viewedAt = "viewed_at"
    }
}

nonisolated struct SearchHistoryRow: Codable, Sendable {
    let query: String
    var searchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case query
        case searchedAt = "searched_at"
    }
}

nonisolated struct NotificationRecord: Decodable, Sendable {
    let id: UUID
    let kind: String
    let productId: UUID?
    let title: String
    let message: String
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, title, message
        case productId = "product_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

nonisolated struct ProductIDParams: Encodable, Sendable {
    let targetProduct: UUID

    enum CodingKeys: String, CodingKey {
        case targetProduct = "target_product"
    }
}

nonisolated struct SearchParams: Encodable, Sendable {
    let query: String
    let maxResults: Int

    enum CodingKeys: String, CodingKey {
        case query
        case maxResults = "max_results"
    }
}

nonisolated struct URLParams: Encodable, Sendable {
    let productUrl: String

    enum CodingKeys: String, CodingKey {
        case productUrl = "product_url"
    }
}

nonisolated struct BarcodeParams: Encodable, Sendable {
    let code: String
}

nonisolated struct URLMatchRow: Decodable, Sendable {
    let productId: UUID
    let confidence: Double
    let matchMethod: String

    enum CodingKeys: String, CodingKey {
        case confidence
        case productId = "product_id"
        case matchMethod = "match_method"
    }
}
