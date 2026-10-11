import Foundation

enum ProductCategory: String, CaseIterable, Identifiable, Hashable {
    case smartphones = "Smartphones"
    case laptops = "Laptops"
    case headphones = "Headphones"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .smartphones: return "iphone.gen3"
        case .laptops: return "laptopcomputer"
        case .headphones: return "headphones"
        }
    }
}

enum Retailer: String, CaseIterable, Identifiable, Hashable {
    case singer = "Singer"
    case abans = "Abans"

    var id: String { rawValue }

    var logoAssetName: String {
        switch self {
        case .singer: return "SingerLogo"
        case .abans: return "AbansLogo"
        }
    }

    var website: String {
        switch self {
        case .singer: return "singersl.com"
        case .abans: return "buyabans.com"
        }
    }
}

struct RetailerListing: Identifiable, Hashable {
    let retailer: Retailer
    let price: Double
    let isAvailable: Bool
    var title: String = ""

    var id: Retailer { retailer }

    init(retailer: Retailer, price: Double, isAvailable: Bool = true, title: String = "") {
        self.retailer = retailer
        self.price = price
        self.isAvailable = isAvailable
        self.title = title
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
    let name: String
    let brand: String
    let category: ProductCategory
    let tagline: String
    let rating: Double
    let baseListings: [RetailerListing]
    let specifications: [Specification]
    let basePriceHistory: [PricePoint]
    let keySpec: String

    init(
        id: UUID,
        name: String,
        brand: String,
        category: ProductCategory,
        tagline: String,
        rating: Double,
        listings: [RetailerListing],
        specifications: [Specification],
        priceHistory: [PricePoint],
        keySpec: String
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.tagline = tagline
        self.rating = rating
        self.baseListings = listings
        self.specifications = specifications
        self.basePriceHistory = priceHistory
        self.keySpec = keySpec
    }

    static func == (lhs: Product, rhs: Product) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var fullName: String { "\(brand) \(name)" }

    /// False for older reference models that Singer and Abans no longer list.
    var isSold: Bool { !baseListings.isEmpty }

    // Live values: read through the observable price book, so any view showing
    // a price re-renders automatically when a price changes.
    var listings: [RetailerListing] { PriceBook.shared.listings(for: self) }
    var priceHistory: [PricePoint] { PriceBook.shared.history(for: self) }

    var valueScore: ValueScore { ValueScoreCalculator.shared.score(for: self) }
    var listingMatch: ListingMatch { ListingMatcher.shared.match(for: self) }

    var barcode: String { CatalogMetadata.barcode(for: self) }

    var imageSymbolName: String {
        switch (brand, name) {
        case ("Apple", "AirPods Max"): return "airpodsmax"
        case ("Apple", "MacBook Air M3"): return "macbook"
        default: return category.symbolName
        }
    }

    var imageAssetName: String? {
        switch (brand, name) {
        case ("Apple", "iPhone 16 Pro"): return "iphone16pro"
        case ("Samsung", "Galaxy S25"): return "galaxys25"
        case ("Google", "Pixel 9"): return "pixel9"
        case ("Xiaomi", "14T Pro"): return "xiaomi14tpro"
        case ("Apple", "MacBook Air M3"): return "macbookairm3"
        case ("ASUS", "Vivobook 15"): return "asusvivobook15"
        case ("Lenovo", "IdeaPad Slim 5"): return "ideapadslim5"
        case ("HP", "Pavilion 14"): return "hppavilion14"
        case ("Sony", "WH-1000XM5"): return "sonywh1000xm5"
        case ("Bose", "QuietComfort Ultra"): return "boseqcultra"
        case ("Apple", "AirPods Max"): return "airpodsmax"
        case ("JBL", "Live 770NC"): return "jbllive770nc"
        case ("Apple", "iPhone 13"): return "iphone13"
        case ("Samsung", "Galaxy S23"): return "galaxys23"
        case ("Apple", "MacBook Air M1"): return "macbookairm1"
        case ("Sony", "WH-1000XM4"): return "sonywh1000xm4"
        case ("Bose", "QuietComfort 45"): return "boseqc45"
        default: return nil
        }
    }

    var lowestListing: RetailerListing {
        listings.min { $0.price < $1.price } ?? listings[0]
    }

    var highestListing: RetailerListing {
        listings.max { $0.price < $1.price } ?? listings[0]
    }

    var startingPrice: Double { lowestListing.price }

    var savings: Double { highestListing.price - lowestListing.price }

    func specValue(for label: String) -> String? {
        specifications.first { $0.label == label }?.value
    }

    func listing(for retailer: Retailer) -> RetailerListing? {
        listings.first { $0.retailer == retailer }
    }
}
