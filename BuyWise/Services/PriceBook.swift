import Foundation
import Observation

/// Mock retailer price feed. Stands in for the proposal's mock price API:
/// base prices come from the curated catalog, and `setPrice` is the
/// "change a price" hook used to demonstrate price-drop alerts.
@Observable
final class PriceBook {
    static let shared = PriceBook()

    private(set) var overrides: [UUID: [Retailer: Double]] = [:]
    private(set) var latestPoint: [UUID: PricePoint] = [:]

    func listings(for product: Product) -> [RetailerListing] {
        product.baseListings.map { base in
            RetailerListing(
                retailer: base.retailer,
                price: overrides[product.id]?[base.retailer] ?? base.price,
                isAvailable: base.isAvailable,
                title: CatalogMetadata.title(for: product, retailer: base.retailer)
            )
        }
    }

    func history(for product: Product) -> [PricePoint] {
        var history = product.basePriceHistory
        if let point = latestPoint[product.id] {
            if let last = history.last, Calendar.current.isDate(last.date, inSameDayAs: point.date) {
                history.removeLast()
            }
            history.append(point)
        }
        return history
    }

    func setPrice(_ price: Double, for product: Product, at retailer: Retailer) {
        overrides[product.id, default: [:]][retailer] = price
        let lowest = listings(for: product).map(\.price).min() ?? price
        latestPoint[product.id] = PricePoint(date: .now, price: lowest)
    }

    func reset() {
        overrides = [:]
        latestPoint = [:]
    }
}
