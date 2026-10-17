import Foundation

enum ProductCategory: String, CaseIterable, Identifiable, Hashable {
    case smartphones = "Smartphones"
    case laptops = "Laptops"
    case headphones = "Headphones"

    var id: String { rawValue }

    /// Value stored in the database `product_category` enum.
    var databaseValue: String { rawValue.lowercased() }

    init?(databaseValue: String) {
        guard let match = Self.allCases.first(where: { $0.databaseValue == databaseValue }) else { return nil }
        self = match
    }

    var symbolName: String {
        switch self {
        case .smartphones: return "iphone.gen3"
        case .laptops: return "laptopcomputer"
        case .headphones: return "headphones"
        }
    }
}

enum Retailer: String, CaseIterable, Identifiable, Hashable {
    case celltronics = "Celltronics"
    case abans = "Abans"

    var id: String { rawValue }

    /// Primary key in the `retailers` table.
    var databaseID: String { rawValue.lowercased() }

    init?(databaseID: String) {
        guard let match = Self.allCases.first(where: { $0.databaseID == databaseID }) else { return nil }
        self = match
    }

    var logoAssetName: String {
        switch self {
        case .celltronics: return "CelltronicsLogo"
        case .abans: return "AbansLogo"
        }
    }

    var website: String {
        switch self {
        case .celltronics: return "celltronics.lk"
        case .abans: return "buyabans.com"
        }
    }
}

struct RetailerListing: Identifiable, Hashable {
    let retailer: Retailer
    let price: Double
    let isAvailable: Bool
    var title: String = ""
    var url: URL?
    var sku: String?
    var originalPrice: Double?
    var isPreorder = false

    var id: Retailer { retailer }

    init(retailer: Retailer, price: Double, isAvailable: Bool = true, title: String = "", url: URL? = nil,
         sku: String? = nil, originalPrice: Double? = nil, isPreorder: Bool = false) {
        self.retailer = retailer
        self.price = price
        self.isAvailable = isAvailable
        self.title = title
        self.url = url
        self.sku = sku
        self.originalPrice = originalPrice
        self.isPreorder = isPreorder
    }
}

struct Specification: Identifiable, Hashable {
    let label: String
    let value: String

    var id: String { label }

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

struct PricePoint: Identifiable, Hashable {
    let date: Date
    let price: Double

    var id: Date { date }
}

struct Product: Identifiable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let brand: String
    let category: ProductCategory
    let tagline: String
    /// Retailers don't publish ratings, so this is only set for the bundled reference devices.
    let rating: Double?
    let baseListings: [RetailerListing]
    let specifications: [Specification]
    let basePriceHistory: [PricePoint]
    let keySpec: String
    let imageURL: URL?
    /// Bundled photo for the reference devices used in upgrade analysis.
    let imageAssetName: String?
    let barcodes: [String]

    init(
        id: UUID,
        slug: String = "",
        name: String,
        brand: String,
        category: ProductCategory,
        tagline: String = "",
        rating: Double? = nil,
        listings: [RetailerListing],
        specifications: [Specification],
        priceHistory: [PricePoint],
        keySpec: String,
        imageURL: URL? = nil,
        imageAssetName: String? = nil,
        barcodes: [String] = []
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.brand = brand
        self.category = category
        self.tagline = tagline
        self.rating = rating
        self.baseListings = listings
        self.specifications = specifications
        self.basePriceHistory = priceHistory
        self.keySpec = keySpec
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.barcodes = barcodes
    }

    static func == (lhs: Product, rhs: Product) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var fullName: String { "\(brand) \(name)" }

    /// False for older reference models that Celltronics and Abans no longer list.
    var isSold: Bool { !listings.isEmpty }

    // Live values: read through the catalogue store, so any view showing a price
    // re-renders automatically when the backend reports a price change.
    var listings: [RetailerListing] { CatalogStore.shared.listings(for: self) }
    var priceHistory: [PricePoint] { CatalogStore.shared.history(for: self) }

    var valueScore: ValueScore { ValueScoreCalculator.shared.score(for: self) }
    var listingMatch: ListingMatch { ListingMatcher.shared.match(for: self) }

    /// Manufacturer EAN when known, otherwise the retailer item code printed on shelf tags.
    var barcode: String { barcodes.first ?? listings.compactMap(\.sku).first ?? "" }

    var imageSymbolName: String {
        switch (brand, category) {
        case ("Apple", .headphones) where name.localizedCaseInsensitiveContains("max"): return "airpodsmax"
        case ("Apple", .laptops): return "macbook"
        default: return category.symbolName
        }
    }

    var lowestListing: RetailerListing {
        listings.min { $0.price < $1.price } ?? Self.unavailable
    }

    var highestListing: RetailerListing {
        listings.max { $0.price < $1.price } ?? Self.unavailable
    }

    /// Stand-in for reference devices that no retailer sells any more.
    private static let unavailable = RetailerListing(retailer: .celltronics, price: 0, isAvailable: false)

    var startingPrice: Double { lowestListing.price }

    var savings: Double { highestListing.price - lowestListing.price }

    func specValue(for label: String) -> String? {
        specifications.first { $0.label == label }?.value
    }

    func listing(for retailer: Retailer) -> RetailerListing? {
        listings.first { $0.retailer == retailer }
    }
}
