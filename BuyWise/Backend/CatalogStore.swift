import Foundation
import CoreLocation
import Observation
import Supabase

/// The live Celltronics/Abans catalogue from Supabase. Products are loaded once; offers and price
/// history refresh per product after a price change so open screens update in place.
@Observable
final class CatalogStore {
    static let shared = CatalogStore()

    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var products: [Product] = []
    private(set) var branches: [StoreBranch] = []
    /// Bumped whenever prices change, so cached value scores know to recompute.
    private(set) var revision = 0

    private var productsByID: [UUID: Product] = [:]
    private var offersByProduct: [UUID: [RetailerListing]] = [:]
    private var historyByProduct: [UUID: [PricePoint]] = [:]

    func listings(for product: Product) -> [RetailerListing] {
        offersByProduct[product.id] ?? product.baseListings
    }

    func history(for product: Product) -> [PricePoint] {
        historyByProduct[product.id] ?? product.basePriceHistory
    }

    func product(id: UUID) -> Product? {
        productsByID[id]
    }

    func loadIfNeeded() async {
        guard state != .loaded, state != .loading else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            async let productRows: [ProductRow] = fetchAll("products", orderedBy: ["id"])
            async let offerRows: [OfferRow] = fetchAll("product_offers", orderedBy: ["product_id", "retailer_id"])
            async let historyRows: [PriceHistoryRow] = fetchAll("product_price_history", orderedBy: ["product_id", "day"])
            async let branchRows: [StoreBranchRecord] = fetchAll("store_branches", orderedBy: ["id"])

            let (rows, offers, history, stores) = try await (productRows, offerRows, historyRows, branchRows)
            offersByProduct = Dictionary(grouping: offers, by: \.productId).mapValues { $0.compactMap(Self.listing) }
            historyByProduct = Dictionary(grouping: history, by: \.productId).mapValues { $0.map(Self.point) }
            products = rows.compactMap(Self.product).sorted { $0.fullName < $1.fullName }
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            branches = stores.compactMap(Self.branch)
            revision += 1
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Re-reads one product's offers and history, e.g. after a simulated price drop.
    func refresh(productID: UUID) async {
        do {
            let offers: [OfferRow] = try await supabase.from("product_offers")
                .select().eq("product_id", value: productID).execute().value
            let history: [PriceHistoryRow] = try await supabase.from("product_price_history")
                .select().eq("product_id", value: productID).order("day").execute().value
            offersByProduct[productID] = offers.compactMap(Self.listing)
            historyByProduct[productID] = history.map(Self.point)
            revision += 1
        } catch {
            // Keep showing the last known prices; the next full load will catch up.
        }
    }

    // PostgREST returns at most 1,000 rows per request: read the total from the first page,
    // then fetch the remaining pages in parallel (price history is several pages).
    private func fetchAll<Row: Decodable & Sendable>(_ table: String, orderedBy columns: [String]) async throws -> [Row] {
        let pageSize = 1000
        let first: PostgrestResponse<[Row]> = try await page(table, columns, from: 0, size: pageSize, counted: true).execute()
        let total = first.count ?? first.value.count
        guard total > pageSize else { return first.value }

        let pages = try await withThrowingTaskGroup(of: (Int, [Row]).self) { group in
            for offset in stride(from: pageSize, to: total, by: pageSize) {
                group.addTask {
                    let rows: [Row] = try await self.page(table, columns, from: offset, size: pageSize, counted: false).execute().value
                    return (offset, rows)
                }
            }
            var results: [(Int, [Row])] = []
            for try await result in group { results.append(result) }
            return results
        }
        return first.value + pages.sorted { $0.0 < $1.0 }.flatMap(\.1)
    }

    private func page(_ table: String, _ columns: [String], from offset: Int, size: Int, counted: Bool) -> PostgrestTransformBuilder {
        var query: PostgrestTransformBuilder = supabase.from(table).select("*", count: counted ? .exact : nil)
        for column in columns { query = query.order(column) }
        return query.range(from: offset, to: offset + size - 1)
    }

    // MARK: Row mapping

    private static func product(_ row: ProductRow) -> Product? {
        guard let category = ProductCategory(databaseValue: row.category) else { return nil }
        return Product(
            id: row.id,
            slug: row.slug,
            name: row.name,
            brand: row.brand,
            category: category,
            tagline: row.tagline ?? "",
            listings: [],
            specifications: row.specs.map { Specification($0.label, $0.value) },
            priceHistory: [],
            keySpec: row.keySpec ?? "",
            imageURL: row.imageUrl.flatMap(URL.init(string:)),
            barcodes: row.barcodes
        )
    }

    private static func listing(_ row: OfferRow) -> RetailerListing? {
        guard let retailer = Retailer(databaseID: row.retailerId) else { return nil }
        return RetailerListing(
            retailer: retailer,
            price: row.price,
            isAvailable: row.inStock,
            title: row.title,
            url: URL(string: row.url),
            sku: row.sku,
            originalPrice: row.originalPrice,
            isPreorder: row.isPreorder
        )
    }

    private static func point(_ row: PriceHistoryRow) -> PricePoint {
        PricePoint(date: row.day, price: row.price)
    }

    private static func branch(_ row: StoreBranchRecord) -> StoreBranch? {
        guard let retailer = Retailer(databaseID: row.retailerId) else { return nil }
        let name = row.name.localizedCaseInsensitiveContains(retailer.rawValue) ? row.name : "\(retailer.rawValue) \(row.name)"
        return StoreBranch(
            id: row.id.uuidString,
            retailer: retailer,
            branchName: name,
            storeType: row.storeType,
            address: [row.address, row.city?.capitalized].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "),
            coordinate: CLLocationCoordinate2D(latitude: row.latitude, longitude: row.longitude),
            openingHours: row.openingHours
        )
    }
}
