import Foundation

// MARK: - Older reference products

/// Models a user may already own. They are no longer sold by Singer or Abans, so they have
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
            Specification("Battery", "Up to 19 hours video"),
            Specification("5G", "Yes")
        ],
        priceHistory: [], keySpec: "A15 Bionic chip"
    )

    static let galaxyS23 = Product(
        id: UUID(), name: "Galaxy S23", brand: "Samsung", category: .smartphones,
        tagline: "Compact flagship with Snapdragon 8 Gen 2", rating: 4.5, listings: [],
        specifications: [
            Specification("Display", "6.1\" Dynamic AMOLED 2X"),
            Specification("Chip", "Snapdragon 8 Gen 2"),
            Specification("Storage", "128GB"),
            Specification("Camera", "50MP Triple Camera"),
            Specification("Battery", "Up to 22 hours video"),
            Specification("5G", "Yes")
        ],
        priceHistory: [], keySpec: "Snapdragon 8 Gen 2"
    )

    static let macBookAirM1 = Product(
        id: UUID(), name: "MacBook Air M1", brand: "Apple", category: .laptops,
        tagline: "The first Apple silicon MacBook Air", rating: 4.8, listings: [],
        specifications: [
            Specification("Display", "13.3\" Retina"),
            Specification("Chip", "Apple M1"),
            Specification("Memory", "8GB Unified Memory"),
            Specification("Storage", "256GB SSD"),
            Specification("Battery", "Up to 18 hours"),
            Specification("Weight", "1.29 kg")
        ],
        priceHistory: [], keySpec: "Apple M1 chip"
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
        priceHistory: [], keySpec: "Foldable, 30-hour battery"
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
        priceHistory: [], keySpec: "Lightweight, 24-hour battery"
    )

    static let referenceProducts = [iPhone13, galaxyS23, macBookAirM1, sonyWH1000XM4, boseQC45]

    /// Everything a user might own: current catalogue plus older reference models.
    static var ownableProducts: [Product] { all + referenceProducts }
}

// MARK: - Upgrade metadata

/// Extra data used only by Upgrade Analysis: benchmark-style scores that aren't in the
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
        // Smartphones
        "Apple iPhone 13": Entry(
            performanceScore: 4_650, cameraScore: 130,
            features: ["Lightning port", "Face ID", "MagSafe charging", "Ceramic Shield", "Water resistance (IP68)"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.0", "Refresh rate": "60Hz"]
        ),
        "Apple iPhone 16 Pro": Entry(
            performanceScore: 8_600, cameraScore: 157,
            features: ["USB-C port", "Face ID", "MagSafe charging", "Ceramic Shield", "Dynamic Island", "Water resistance (IP68)",
                       "Action Button", "Camera Control", "Always-On display", "5x telephoto camera", "Satellite SOS"],
            versioned: ["Wi-Fi": "7", "Bluetooth": "5.3", "Refresh rate": "120Hz"]
        ),
        "Samsung Galaxy S23": Entry(
            performanceScore: 5_000, cameraScore: 136,
            features: ["USB-C port", "In-display fingerprint", "Wireless charging", "Reverse wireless charging", "Water resistance (IP68)"],
            versioned: ["Wi-Fi": "6E", "Bluetooth": "5.3", "Refresh rate": "120Hz", "OS updates": "4 years"]
        ),
        "Samsung Galaxy S25": Entry(
            performanceScore: 9_800, cameraScore: 142,
            features: ["USB-C port", "In-display fingerprint", "Wireless charging", "Reverse wireless charging", "Water resistance (IP68)", "Galaxy AI features"],
            versioned: ["Wi-Fi": "7", "Bluetooth": "5.4", "Refresh rate": "120Hz", "OS updates": "7 years"]
        ),
        "Google Pixel 9": Entry(
            performanceScore: 4_700, cameraScore: 151,
            features: ["USB-C port", "In-display fingerprint", "Face Unlock", "Wireless charging", "Water resistance (IP68)", "Satellite SOS", "Gemini AI features"],
            versioned: ["Wi-Fi": "7", "Bluetooth": "5.3", "Refresh rate": "120Hz", "OS updates": "7 years"]
        ),
        "Xiaomi 14T Pro": Entry(
            performanceScore: 7_300, cameraScore: 145,
            features: ["USB-C port", "In-display fingerprint", "Wireless charging", "Water resistance (IP68)", "Leica cameras", "120W fast charging"],
            versioned: ["Wi-Fi": "7", "Bluetooth": "5.4", "Refresh rate": "144Hz", "OS updates": "5 years"]
        ),

        // Laptops
        "Apple MacBook Air M1": Entry(
            performanceScore: 7_600,
            features: ["Touch ID", "Backlit keyboard", "Fanless design", "Thunderbolt / USB 4"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.0", "Webcam": "720p", "External displays": "1"]
        ),
        "Apple MacBook Air M3": Entry(
            performanceScore: 12_000,
            features: ["Touch ID", "Backlit keyboard", "Fanless design", "Thunderbolt / USB 4", "MagSafe charging"],
            versioned: ["Wi-Fi": "6E", "Bluetooth": "5.3", "Webcam": "1080p", "External displays": "2"]
        ),
        "ASUS Vivobook 15": Entry(
            performanceScore: 7_100,
            features: ["Fingerprint reader", "Backlit keyboard", "Numeric keypad"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.0", "Webcam": "720p"]
        ),
        "Lenovo IdeaPad Slim 5": Entry(
            performanceScore: 6_000,
            features: ["Fingerprint reader", "Backlit keyboard", "Webcam privacy shutter"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.1", "Webcam": "1080p"]
        ),
        "HP Pavilion 14": Entry(
            performanceScore: 7_600,
            features: ["Fingerprint reader", "Backlit keyboard", "Touchscreen", "B&O audio"],
            versioned: ["Wi-Fi": "6", "Bluetooth": "5.3", "Webcam": "720p"]
        ),

        // Headphones
        "Sony WH-1000XM4": Entry(features: ["Ambient sound mode", "Multipoint connection", "Speak-to-Chat", "LDAC hi-res audio", "Touch controls", "USB-C charging", "Foldable design"]),
        "Sony WH-1000XM5": Entry(features: ["Ambient sound mode", "Multipoint connection", "Speak-to-Chat", "LDAC hi-res audio", "Touch controls", "USB-C charging", "Auto noise cancelling optimiser"]),
        "Apple AirPods Max": Entry(features: ["Spatial audio", "Digital Crown", "Ambient sound mode", "USB-C charging", "Automatic device switching"]),
        "Bose QuietComfort 45": Entry(features: ["Ambient sound mode", "Multipoint connection", "USB-C charging", "Foldable design"]),
        "Bose QuietComfort Ultra": Entry(features: ["Ambient sound mode", "Multipoint connection", "USB-C charging", "Foldable design", "Immersive audio", "CustomTune"]),
        "JBL Live 770NC": Entry(features: ["Ambient sound mode", "Multipoint connection", "USB-C charging", "Foldable design", "Spatial sound"])
    ]
}
