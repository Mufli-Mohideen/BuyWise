import Foundation

/// Retailer-specific listing data. Singer and Abans name the same product
/// differently, which is exactly what the listing matcher has to resolve.
enum CatalogMetadata {
    struct Entry {
        let singerTitle: String
        let abansTitle: String
        let barcode: String
        /// Similar-looking listings from the same stores that must NOT be treated as this product.
        let lookalikes: [(Retailer, String)]
    }

    static let entries: [String: Entry] = [
        "Apple iPhone 16 Pro": Entry(
            singerTitle: "Apple iPhone 16 Pro 256GB Natural Titanium",
            abansTitle: "iPhone 16 Pro (256 GB) - Natural Titanium",
            barcode: "0195949771231",
            lookalikes: [(.singer, "Apple iPhone 16 Pro 128GB Natural Titanium"), (.abans, "iPhone 16 Pro Max (256 GB) - Black Titanium")]
        ),
        "Samsung Galaxy S25": Entry(
            singerTitle: "Samsung Galaxy S25 5G 12GB/256GB Icy Blue",
            abansTitle: "SAMSUNG GALAXY S25 (256GB) ICYBLUE",
            barcode: "8806095864551",
            lookalikes: [(.abans, "SAMSUNG GALAXY S25 ULTRA (256GB) TITANIUM"), (.singer, "Samsung Galaxy S24 5G 8GB/256GB Marble Grey")]
        ),
        "Google Pixel 9": Entry(
            singerTitle: "Google Pixel 9 5G 128GB Peony",
            abansTitle: "GOOGLE PIXEL 9 128GB PEONY",
            barcode: "0840244706784",
            lookalikes: [(.abans, "GOOGLE PIXEL 9 PRO 128GB OBSIDIAN")]
        ),
        "Xiaomi 14T Pro": Entry(
            singerTitle: "Xiaomi 14T Pro 5G 12GB/512GB Titan Blue",
            abansTitle: "XIAOMI 14T PRO (512GB) TITAN BLUE",
            barcode: "6941812789445",
            lookalikes: [(.singer, "Xiaomi 14T 5G 12GB/256GB Titan Gray")]
        ),
        "Apple MacBook Air M3": Entry(
            singerTitle: "Apple MacBook Air 13\" M3 Chip 8GB 256GB SSD Midnight",
            abansTitle: "MacBook Air 13-inch M3 (8GB/256GB) Midnight",
            barcode: "0195949143288",
            lookalikes: [(.abans, "MacBook Air 13-inch M2 (8GB/256GB) Midnight"), (.singer, "Apple MacBook Air 15\" M3 Chip 8GB 256GB SSD Starlight")]
        ),
        "ASUS Vivobook 15": Entry(
            singerTitle: "ASUS Vivobook 15 X1502ZA Core i5-1235U 16GB 512GB SSD",
            abansTitle: "ASUS VIVOBOOK 15 (X1502ZA) i5 12TH GEN 16GB/512GB",
            barcode: "4711387087341",
            lookalikes: []
        ),
        "Lenovo IdeaPad Slim 5": Entry(
            singerTitle: "Lenovo IdeaPad Slim 5 14\" Ryzen 5 7530U 16GB 512GB",
            abansTitle: "LENOVO IDEAPAD SLIM 5 14ABR8 RYZEN 5 16GB/512GB",
            barcode: "0196802547219",
            lookalikes: [(.singer, "Lenovo IdeaPad Slim 3 15\" Ryzen 5 7520U 8GB 512GB")]
        ),
        "HP Pavilion 14": Entry(
            singerTitle: "HP Pavilion 14-ek1010TU Core i5-1335U 16GB 512GB Silver",
            abansTitle: "HP PAVILION 14 EK1010TU i5 13TH GEN 16GB/512GB",
            barcode: "0197497132908",
            lookalikes: []
        ),
        "Sony WH-1000XM5": Entry(
            singerTitle: "Sony WH1000XM5 Wireless Noise Cancelling Headphones Black",
            abansTitle: "SONY WH-1000XM5 Noise Canceling Headphone (Black)",
            barcode: "4548736132597",
            lookalikes: [(.abans, "SONY WH-1000XM4 Noise Canceling Headphone (Black)")]
        ),
        "Apple AirPods Max": Entry(
            singerTitle: "Apple AirPods Max USB-C Midnight",
            abansTitle: "AirPods Max (USB-C) - Midnight",
            barcode: "0195949487870",
            lookalikes: [(.singer, "Apple AirPods Pro 2 USB-C")]
        ),
        "Bose QuietComfort Ultra": Entry(
            singerTitle: "Bose QuietComfort Ultra Wireless Headphones Black",
            abansTitle: "BOSE QC ULTRA HEADPHONES - BLACK",
            barcode: "0017817846714",
            lookalikes: [(.abans, "BOSE QUIETCOMFORT 45 HEADPHONES - BLACK")]
        ),
        "JBL Live 770NC": Entry(
            singerTitle: "JBL Live 770NC Wireless Over-Ear Headphones Black",
            abansTitle: "JBL LIVE 770NC ADAPTIVE NC HEADPHONE BLACK",
            barcode: "6925281965664",
            lookalikes: [(.singer, "JBL Tune 770NC Wireless Over-Ear Headphones Black")]
        )
    ]

    static func entry(for product: Product) -> Entry? {
        entries[product.fullName]
    }

    static func title(for product: Product, retailer: Retailer) -> String {
        guard let entry = entry(for: product) else { return product.fullName }
        return retailer == .singer ? entry.singerTitle : entry.abansTitle
    }

    static func barcode(for product: Product) -> String {
        entry(for: product)?.barcode ?? ""
    }

    static func product(forBarcode code: String) -> Product? {
        let digits = code.filter(\.isNumber)
        return ProductCatalog.all.first { barcode(for: $0) == digits }
    }

    static func sampleURL(for product: Product, retailer: Retailer) -> String {
        let slug = title(for: product, retailer: retailer)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "https://www.\(retailer.website)/product/\(slug)"
    }
}
