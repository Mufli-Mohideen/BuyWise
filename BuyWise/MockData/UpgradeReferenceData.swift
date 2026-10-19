import Foundation

// MARK: - Older reference products

/// Models a user may already own. They are no longer sold by Celltronics, Abans or Singer, so they have
/// no listings and only appear as the "current product" in Upgrade Analysis.
extension ProductCatalog {
    static let iPhone13 = Product(
        id: UUID(), name: "iPhone 13", brand: "Apple", category: .smartphones,
        tagline: "Dual-camera iPhone with the A15 Bionic chip", rating: 4.6, listings: [],
        specifications: [
            Specification("Display", "6.1\" Super Retina XDR"),
            Specification("Chip", "A15 Bionic"),
            Specification("Storage", "128GB"),
            Specification("Camera", "12MP Dual Camera"),
            Specification("Memory", "4GB"),
            Specification("Battery", "3240 mAh"),
            Specification("5G", "Yes")
        ],
        priceHistory: [], keySpec: "A15 Bionic chip", imageAssetName: "iphone13"
    )

    static let galaxyS23 = Product(
        id: UUID(), name: "Galaxy S23", brand: "Samsung", category: .smartphones,
        tagline: "Compact flagship with Snapdragon 8 Gen 2", rating: 4.5, listings: [],
        specifications: [
            Specification("Display", "6.1\" Dynamic AMOLED 2X"),
            Specification("Chip", "Snapdragon 8 Gen 2"),
            Specification("Storage", "128GB"),
            Specification("Camera", "50MP Triple Camera"),
            Specification("Memory", "8GB"),
            Specification("Battery", "3900 mAh"),
            Specification("5G", "Yes")
        ],
        priceHistory: [], keySpec: "Snapdragon 8 Gen 2", imageAssetName: "galaxys23"
    )

    static let macBookAirM1 = Product(
        id: UUID(), name: "MacBook Air M1", brand: "Apple", category: .laptops,
        tagline: "The first Apple silicon MacBook Air", rating: 4.8, listings: [],
        specifications: [
            Specification("Display", "13.3\" Retina"),
            Specification("Chip", "Apple M1"),
            Specification("Memory", "8GB Unified Memory"),
            Specification("Storage", "256GB SSD"),
            Specification("Battery", "49.9 Wh"),
            Specification("Weight", "1.29 kg")
        ],
        priceHistory: [], keySpec: "Apple M1 chip", imageAssetName: "macbookairm1"
    )

    static let sonyWH1000XM4 = Product(
        id: UUID(), name: "WH-1000XM4", brand: "Sony", category: .headphones,
        tagline: "Wireless Noise Cancelling Headphones", rating: 4.7, listings: [],
        specifications: [
            Specification("Driver", "40mm"),
            Specification("Battery", "Up to 30 hours"),
            Specification("Weight", "254g"),
            Specification("Connectivity", "Bluetooth 5.0"),
            Specification("Noise Cancellation", "Yes")
        ],
        priceHistory: [], keySpec: "Foldable, 30-hour battery", imageAssetName: "sonywh1000xm4"
    )

    static let boseQC45 = Product(
        id: UUID(), name: "QuietComfort 45", brand: "Bose", category: .headphones,
        tagline: "Comfortable noise cancelling headphones", rating: 4.5, listings: [],
        specifications: [
            Specification("Driver", "35mm"),
            Specification("Battery", "Up to 24 hours"),
            Specification("Weight", "240g"),
            Specification("Connectivity", "Bluetooth 5.1"),
            Specification("Noise Cancellation", "Yes")
        ],
        priceHistory: [], keySpec: "Lightweight, 24-hour battery", imageAssetName: "boseqc45"
    )

    static let referenceProducts = [iPhone13, galaxyS23, macBookAirM1, sonyWH1000XM4, boseQC45]

    /// Everything a user might own: current catalogue plus older reference models.
    static var ownableProducts: [Product] { all + referenceProducts }
}

// MARK: - Upgrade metadata

/// Extra data for the reference devices used in Upgrade Analysis: benchmark-style scores that aren't in the
/// specification sheet, and feature lists for the gained / lost / unchanged comparison.
enum UpgradeReferenceData {
    struct Entry {
        var performanceScore: Double? = nil
        var cameraScore: Double? = nil
        /// Plain features, compared as present / absent.
        var features: [String] = []
        /// Features with a version or value, compared as changed when the value differs.
        var versioned: [String: String] = [:]
    }

    static func entry(for product: Product) -> Entry? {
        entries[product.fullName]
    }

    private static let entries: [String: Entry] = [
        "Apple iPhone 13": Entry(
            performanceScore: 4_650, cameraScore: 130,
            features: ["Lightning port", "Face ID", "MagSafe charging", "Ceramic Shield", "Water resistance (IP68)"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.0", "Refresh rate": "60Hz"]
        ),
        "Samsung Galaxy S23": Entry(
            performanceScore: 5_000, cameraScore: 136,
            features: ["USB-C port", "In-display fingerprint", "Wireless charging", "Reverse wireless charging", "Water resistance (IP68)"],
            versioned: ["Wi-Fi": "6E", "Bluetooth": "5.3", "Refresh rate": "120Hz", "OS updates": "4 years"]
        ),
        "Apple MacBook Air M1": Entry(
            performanceScore: 7_600,
            features: ["Touch ID", "Backlit keyboard", "Fanless design", "Thunderbolt / USB 4"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.0", "Webcam": "720p", "External displays": "1"]
        ),
        "Sony WH-1000XM4": Entry(features: ["Ambient sound mode", "Multipoint connection", "Speak-to-Chat", "LDAC hi-res audio", "Touch controls", "USB-C charging", "Foldable design"]),
        "Bose QuietComfort 45": Entry(features: ["Ambient sound mode", "Multipoint connection", "USB-C charging", "Foldable design"])
    ]
}
