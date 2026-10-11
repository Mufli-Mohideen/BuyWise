import Foundation

enum ProductCatalog {

    // MARK: - Smartphones

    static let iPhone16Pro = Product(
        id: UUID(),
        name: "iPhone 16 Pro",
        brand: "Apple",
        category: .smartphones,
        tagline: "Titanium design with the A18 Pro chip",
        rating: 4.8,
        listings: [
            RetailerListing(retailer: .singer, price: 349_900),
            RetailerListing(retailer: .abans, price: 344_900)
        ],
        specifications: [
            Specification("Display", "6.3\" Super Retina XDR"),
            Specification("Chip", "A18 Pro"),
            Specification("Storage", "256GB"),
            Specification("Camera", "48MP Triple Camera"),
            Specification("Battery", "Up to 27 hours video"),
            Specification("5G", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 359_900), (75, 359_900), (60, 354_900), (45, 352_900),
            (30, 349_900), (15, 347_900), (7, 344_900), (0, 344_900)
        ]),
        keySpec: "A18 Pro chip"
    )

    static let galaxyS25 = Product(
        id: UUID(),
        name: "Galaxy S25",
        brand: "Samsung",
        category: .smartphones,
        tagline: "Flagship performance with Galaxy AI",
        rating: 4.6,
        listings: [
            RetailerListing(retailer: .singer, price: 249_900),
            RetailerListing(retailer: .abans, price: 254_900)
        ],
        specifications: [
            Specification("Display", "6.2\" Dynamic AMOLED 2X"),
            Specification("Chip", "Snapdragon 8 Elite"),
            Specification("Storage", "256GB"),
            Specification("Camera", "50MP Triple Camera"),
            Specification("Battery", "Up to 26 hours video"),
            Specification("5G", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 259_900), (75, 257_900), (60, 254_900), (45, 252_900),
            (30, 249_900), (15, 249_900), (7, 249_900), (0, 249_900)
        ]),
        keySpec: "Snapdragon 8 Elite"
    )

    static let pixel9 = Product(
        id: UUID(),
        name: "Pixel 9",
        brand: "Google",
        category: .smartphones,
        tagline: "Smart, capable and refreshingly simple",
        rating: 4.5,
        listings: [
            RetailerListing(retailer: .singer, price: 219_900),
            RetailerListing(retailer: .abans, price: 214_900)
        ],
        specifications: [
            Specification("Display", "6.3\" Actua OLED"),
            Specification("Chip", "Google Tensor G4"),
            Specification("Storage", "128GB"),
            Specification("Camera", "50MP Dual Camera"),
            Specification("Battery", "Up to 24 hours"),
            Specification("5G", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 224_900), (75, 224_900), (60, 222_900), (45, 219_900),
            (30, 219_900), (15, 217_900), (7, 214_900), (0, 214_900)
        ]),
        keySpec: "Tensor G4 with Gemini AI"
    )

    static let xiaomi14TPro = Product(
        id: UUID(),
        name: "14T Pro",
        brand: "Xiaomi",
        category: .smartphones,
        tagline: "Leica optics with flagship-tier speed",
        rating: 4.4,
        listings: [
            RetailerListing(retailer: .singer, price: 174_900),
            RetailerListing(retailer: .abans, price: 169_900)
        ],
        specifications: [
            Specification("Display", "6.67\" AMOLED 144Hz"),
            Specification("Chip", "Dimensity 9300+"),
            Specification("Storage", "512GB"),
            Specification("Camera", "50MP Leica Triple Camera"),
            Specification("Battery", "Up to 30 hours"),
            Specification("5G", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 184_900), (75, 182_900), (60, 179_900), (45, 176_900),
            (30, 174_900), (15, 172_900), (7, 169_900), (0, 169_900)
        ]),
        keySpec: "Leica optics, 512GB storage"
    )

    // MARK: - Laptops

    static let macBookAirM3 = Product(
        id: UUID(),
        name: "MacBook Air M3",
        brand: "Apple",
        category: .laptops,
        tagline: "Strikingly thin, remarkably capable",
        rating: 4.9,
        listings: [
            RetailerListing(retailer: .singer, price: 379_900),
            RetailerListing(retailer: .abans, price: 369_900)
        ],
        specifications: [
            Specification("Display", "13.6\" Liquid Retina"),
            Specification("Chip", "Apple M3"),
            Specification("Memory", "8GB Unified Memory"),
            Specification("Storage", "256GB SSD"),
            Specification("Battery", "Up to 18 hours"),
            Specification("Weight", "1.24 kg")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 389_900), (75, 386_900), (60, 384_900), (45, 379_900),
            (30, 379_900), (15, 374_900), (7, 369_900), (0, 369_900)
        ]),
        keySpec: "Apple M3 chip"
    )

    static let asusVivobook15 = Product(
        id: UUID(),
        name: "Vivobook 15",
        brand: "ASUS",
        category: .laptops,
        tagline: "Everyday performance, everyday price",
        rating: 4.2,
        listings: [
            RetailerListing(retailer: .singer, price: 159_900),
            RetailerListing(retailer: .abans, price: 154_900)
        ],
        specifications: [
            Specification("Display", "15.6\" FHD"),
            Specification("Chip", "Intel Core i5-1235U"),
            Specification("Memory", "16GB RAM"),
            Specification("Storage", "512GB SSD"),
            Specification("Battery", "Up to 10 hours"),
            Specification("Weight", "1.70 kg")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 164_900), (75, 162_900), (60, 159_900), (45, 159_900),
            (30, 157_900), (15, 154_900), (7, 154_900), (0, 154_900)
        ]),
        keySpec: "16GB RAM, 512GB SSD"
    )

    static let ideaPadSlim5 = Product(
        id: UUID(),
        name: "IdeaPad Slim 5",
        brand: "Lenovo",
        category: .laptops,
        tagline: "Slim, sturdy and dependable",
        rating: 4.3,
        listings: [
            RetailerListing(retailer: .singer, price: 189_900),
            RetailerListing(retailer: .abans, price: 194_900)
        ],
        specifications: [
            Specification("Display", "14\" WUXGA"),
            Specification("Chip", "AMD Ryzen 5 7530U"),
            Specification("Memory", "16GB RAM"),
            Specification("Storage", "512GB SSD"),
            Specification("Battery", "Up to 12 hours"),
            Specification("Weight", "1.50 kg")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 194_900), (75, 192_900), (60, 189_900), (45, 189_900),
            (30, 189_900), (15, 189_900), (7, 189_900), (0, 189_900)
        ]),
        keySpec: "AMD Ryzen 5, 16GB RAM"
    )

    static let pavilion14 = Product(
        id: UUID(),
        name: "Pavilion 14",
        brand: "HP",
        category: .laptops,
        tagline: "A touch of style for daily tasks",
        rating: 4.1,
        listings: [
            RetailerListing(retailer: .singer, price: 169_900),
            RetailerListing(retailer: .abans, price: 164_900)
        ],
        specifications: [
            Specification("Display", "14\" FHD Touch"),
            Specification("Chip", "Intel Core i5-1335U"),
            Specification("Memory", "16GB RAM"),
            Specification("Storage", "512GB SSD"),
            Specification("Battery", "Up to 11 hours"),
            Specification("Weight", "1.40 kg")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 174_900), (75, 172_900), (60, 169_900), (45, 169_900),
            (30, 167_900), (15, 164_900), (7, 164_900), (0, 164_900)
        ]),
        keySpec: "Touchscreen display"
    )

    // MARK: - Headphones

    static let sonyWH1000XM5 = Product(
        id: UUID(),
        name: "WH-1000XM5",
        brand: "Sony",
        category: .headphones,
        tagline: "Wireless Noise Cancelling Headphones",
        rating: 4.8,
        listings: [
            RetailerListing(retailer: .singer, price: 94_990),
            RetailerListing(retailer: .abans, price: 89_990)
        ],
        specifications: [
            Specification("Driver", "30mm"),
            Specification("Battery", "Up to 30 hours"),
            Specification("Weight", "250g"),
            Specification("Connectivity", "Bluetooth 5.2"),
            Specification("Noise Cancellation", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 95_990), (80, 97_990), (70, 94_990), (60, 91_990),
            (55, 87_990), (45, 90_990), (35, 93_990), (25, 94_990),
            (15, 94_990), (7, 94_990), (3, 89_990), (0, 89_990)
        ]),
        keySpec: "Industry-leading noise cancellation"
    )

    static let airPodsMax = Product(
        id: UUID(),
        name: "AirPods Max",
        brand: "Apple",
        category: .headphones,
        tagline: "High-fidelity sound, seamlessly personal",
        rating: 4.6,
        listings: [
            RetailerListing(retailer: .singer, price: 149_900),
            RetailerListing(retailer: .abans, price: 154_900)
        ],
        specifications: [
            Specification("Driver", "40mm Apple-designed"),
            Specification("Battery", "Up to 20 hours"),
            Specification("Weight", "385g"),
            Specification("Connectivity", "Bluetooth 5.0"),
            Specification("Noise Cancellation", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 154_900), (75, 154_900), (60, 152_900), (45, 149_900),
            (30, 149_900), (15, 149_900), (7, 149_900), (0, 149_900)
        ]),
        keySpec: "Spatial audio support"
    )

    static let boseQCUltra = Product(
        id: UUID(),
        name: "QuietComfort Ultra",
        brand: "Bose",
        category: .headphones,
        tagline: "Immersive audio, world-class quiet",
        rating: 4.7,
        listings: [
            RetailerListing(retailer: .singer, price: 94_490),
            RetailerListing(retailer: .abans, price: 92_990)
        ],
        specifications: [
            Specification("Driver", "35mm"),
            Specification("Battery", "Up to 24 hours"),
            Specification("Weight", "253g"),
            Specification("Connectivity", "Bluetooth 5.3"),
            Specification("Noise Cancellation", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 97_990), (75, 96_490), (60, 94_990), (45, 94_490),
            (30, 93_990), (15, 92_990), (7, 92_990), (0, 92_990)
        ]),
        keySpec: "Similar features to WH-1000XM5"
    )

    static let jblLive770NC = Product(
        id: UUID(),
        name: "Live 770NC",
        brand: "JBL",
        category: .headphones,
        tagline: "All-day comfort with adaptive noise cancelling",
        rating: 4.2,
        listings: [
            RetailerListing(retailer: .singer, price: 24_990),
            RetailerListing(retailer: .abans, price: 22_990)
        ],
        specifications: [
            Specification("Driver", "40mm"),
            Specification("Battery", "Up to 44 hours"),
            Specification("Weight", "256g"),
            Specification("Connectivity", "Bluetooth 5.3"),
            Specification("Noise Cancellation", "Yes")
        ],
        priceHistory: PriceHistoryFactory.build([
            (90, 27_990), (75, 26_990), (60, 25_990), (45, 24_990),
            (30, 24_990), (15, 23_990), (7, 22_990), (0, 22_990)
        ]),
        keySpec: "44-hour battery life"
    )

    // MARK: - Collections

    static let smartphones = [iPhone16Pro, galaxyS25, pixel9, xiaomi14TPro]
    static let laptops = [macBookAirM3, asusVivobook15, ideaPadSlim5, pavilion14]
    static let headphones = [sonyWH1000XM5, airPodsMax, boseQCUltra, jblLive770NC]

    static let all = smartphones + laptops + headphones

    static let demoIdentifiedProduct = sonyWH1000XM5

    static func alternatives(for product: Product, limit: Int = 3) -> [Product] {
        all.filter { $0.category == product.category && $0.id != product.id }
            .sorted { $0.valueScore.overall > $1.valueScore.overall }
            .prefix(limit)
            .map { $0 }
    }
}
