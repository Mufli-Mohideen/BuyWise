import Foundation
import ImageIO
import UIKit

/// A product's current best price, as shown in the widgets.
struct ProductSnapshot: Identifiable {
    let id: UUID
    let name: String
    let price: Double
    let regularPrice: Double?
    let retailer: String
    let storeCount: Int
    var history: [PricePoint] = []
    var image: UIImage?

    struct PricePoint {
        let day: Date
        let price: Double
    }

    /// Discount off the retailer's regular price, e.g. 0.23 for 23% off.
    var discount: Double? {
        guard let regularPrice, regularPrice > price else { return nil }
        return (regularPrice - price) / regularPrice
    }

    /// Price change across the recorded history, e.g. -0.05 when it's 5% cheaper than the first point.
    var historyChange: Double? {
        guard let first = history.first?.price, history.count > 1, first > 0 else { return nil }
        return (price - first) / first
    }

    var deepLink: URL { URL(string: "buywise://product/\(id.uuidString)")! }
}

/// Reads the public catalogue straight from Supabase. The widget can't share the app's data
/// without an App Group, which free developer accounts don't support.
enum WidgetCatalog {
    private static let baseURL = URL(string: "https://zjrcucrduuwjztwaypcn.supabase.co/rest/v1")!
    private static let anonKey = "sb_publishable_xBk5BN2sP0Rx0gfVwg0TiQ_C0oAkwLE"

    private struct OfferRow: Decodable {
        let retailerId: String
        let price: Double
        let originalPrice: Double?
        let inStock: Bool
    }

    private struct HistoryRow: Decodable {
        let day: Date
        let price: Double
    }

    private struct ProductRow: Decodable {
        let id: UUID
        let name: String
        let brand: String
        let imageUrl: String?
        let productOffers: [OfferRow]?
        let productPriceHistory: [HistoryRow]?
    }

    /// Products the retailers have discounted on their own sites, biggest discount first.
    static func deals(limit: Int) async throws -> [ProductSnapshot] {
        let rows: [ProductRow] = try await get("products", [
            URLQueryItem(name: "select", value: "id,name,brand,image_url,product_offers(retailer_id,price,original_price,in_stock)"),
        ])
        let deals = rows.compactMap(snapshot)
            .filter { $0.discount != nil }
            .sorted { $0.discount! > $1.discount! }
            .prefix(limit)
        return await withImages(Array(deals), from: rows)
    }

    static func product(id: UUID) async throws -> ProductSnapshot? {
        let rows: [ProductRow] = try await get("products", [
            URLQueryItem(name: "select", value: "id,name,brand,image_url,product_offers(retailer_id,price,original_price,in_stock),product_price_history(day,price)"),
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "product_price_history.order", value: "day.asc"),
        ])
        guard let row = rows.first, var product = snapshot(row) else { return nil }
        product.history = (row.productPriceHistory ?? []).map { .init(day: $0.day, price: $0.price) }.sorted { $0.day < $1.day }
        product.image = await thumbnail(row.imageUrl)
        return product
    }

    /// Product names for the widget's product picker.
    static func productNames(matching text: String? = nil, ids: [UUID]? = nil) async throws -> [(id: UUID, name: String)] {
        var query = [
            URLQueryItem(name: "select", value: "id,name,brand"),
            URLQueryItem(name: "order", value: "brand,name"),
        ]
        if let ids {
            query.append(URLQueryItem(name: "id", value: "in.(\(ids.map(\.uuidString).joined(separator: ",")))"))
        }
        // Strip characters PostgREST uses for its own syntax.
        let term = (text ?? "").filter { !",()*%".contains($0) }.trimmingCharacters(in: .whitespaces)
        if !term.isEmpty {
            query.append(URLQueryItem(name: "or", value: "(name.ilike.*\(term)*,brand.ilike.*\(term)*)"))
        }
        let rows: [ProductRow] = try await get("products", query)
        return rows.map { ($0.id, fullName($0)) }
    }

    // MARK: Helpers

    /// Matches the app: the lowest price wins, and it's a deal when that listing is in stock below its regular price.
    private static func snapshot(_ row: ProductRow) -> ProductSnapshot? {
        let offers = row.productOffers ?? []
        guard let lowest = offers.min(by: { $0.price < $1.price }) else { return nil }
        return ProductSnapshot(
            id: row.id,
            name: fullName(row),
            price: lowest.price,
            regularPrice: lowest.inStock ? lowest.originalPrice : nil,
            retailer: retailerName(lowest.retailerId),
            storeCount: offers.count
        )
    }

    private static func fullName(_ row: ProductRow) -> String {
        row.name.lowercased().hasPrefix(row.brand.lowercased()) ? row.name : "\(row.brand) \(row.name)"
    }

    private static func retailerName(_ id: String) -> String {
        switch id {
        case "celltronics": "Celltronics"
        case "abans": "Abans"
        case "singer": "Singer"
        default: id.capitalized
        }
    }

    private static func withImages(_ products: [ProductSnapshot], from rows: [ProductRow]) async -> [ProductSnapshot] {
        let urls = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.imageUrl) })
        return await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, product) in products.enumerated() {
                group.addTask { (index, await thumbnail(urls[product.id] ?? nil)) }
            }
            var result = products
            for await (index, image) in group { result[index].image = image }
            return result
        }
    }

    /// Widgets have a tight memory limit, so decode a small thumbnail instead of the full photo.
    private static func thumbnail(_ string: String?, maxPixels: Int = 240) async -> UIImage? {
        guard let string, let url = URL(string: string),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func get<T: Decodable>(_ table: String, _ query: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: table), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(T.self, from: data)
    }
}
