import Foundation

/// Read-only access to the catalogue loaded by `CatalogStore`.
enum ProductCatalog {
    static var all: [Product] { CatalogStore.shared.products }

    static func products(in category: ProductCategory) -> [Product] {
        all.filter { $0.category == category }
    }

    static func product(id: UUID) -> Product? {
        CatalogStore.shared.product(id: id) ?? referenceProducts.first { $0.id == id }
    }

    /// Best-value products sold by more than one retailer. Used wherever the app needs an example product.
    static func featured(_ category: ProductCategory, count: Int = 1) -> [Product] {
        let sold = products(in: category).filter(\.isSold)
        let comparable = sold.filter { $0.listings.count > 1 && !$0.lowestListing.isPreorder }
        let pool = comparable.isEmpty ? sold : comparable
        return Array(pool.sorted { $0.valueScore.overall > $1.valueScore.overall }.prefix(count))
    }

    /// One featured product per category: phone, laptop, headphones.
    static var featuredTrio: [Product] {
        ProductCategory.allCases.compactMap { featured($0).first }
    }

    static func alternatives(for product: Product, limit: Int = 3) -> [Product] {
        products(in: product.category)
            .filter { $0.id != product.id && $0.isSold }
            .sorted { $0.valueScore.overall > $1.valueScore.overall }
            .prefix(limit)
            .map { $0 }
    }

    /// Products discounted on the retailers' own sites, biggest discount first. Ignores the simulated history.
    static var priceDrops: [(product: Product, previousPrice: Double)] {
        all.compactMap { product -> (product: Product, previousPrice: Double)? in
            guard product.isSold else { return nil }
            let listing = product.lowestListing
            guard listing.isAvailable, let regular = listing.originalPrice, regular > listing.price else { return nil }
            return (product, regular)
        }
        .sorted {
            ($0.previousPrice - $0.product.startingPrice) / $0.previousPrice
                > ($1.previousPrice - $1.product.startingPrice) / $1.previousPrice
        }
    }
}

/// Store branches listed on the retailers' websites.
enum StoreBranches {
    static var all: [StoreBranch] { CatalogStore.shared.branches }

    static func sortedByDistance(_ retailer: Retailer? = nil) -> [StoreBranch] {
        all.filter { retailer == nil || $0.retailer == retailer }
            .sorted { LocationProvider.shared.distance(to: $0) < LocationProvider.shared.distance(to: $1) }
    }

    static func nearest(_ retailer: Retailer) -> StoreBranch? {
        all.filter { $0.retailer == retailer }
            .min { LocationProvider.shared.distance(to: $0) < LocationProvider.shared.distance(to: $1) }
    }
}
