import Foundation
import Observation

enum ShoppingPriority: String, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case battery = "Battery life"
    case performance = "Performance"
    case portability = "Lightweight"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .balanced: return "scalemass"
        case .battery: return "battery.100.bolt"
        case .performance: return "bolt.fill"
        case .portability: return "feather"
        }
    }

    var detail: String {
        switch self {
        case .balanced: return "Weigh every specification equally"
        case .battery: return "Favour longer battery life"
        case .performance: return "Favour faster chips, more memory and storage"
        case .portability: return "Favour lighter products"
        }
    }
}

struct ValueScore: Hashable {
    let overall: Double
    /// Value density (D), 0–10: specification score relative to price, within the category.
    let specificationValue: Double
    /// Price position (P), 0–10: current price vs the category average (average = 5).
    let pricePosition: Double
    /// Price stability (H), 0–10: how little the price has moved over its recorded history.
    let priceStability: Double
    let specDetail: String
    let priceDetail: String
    let historyDetail: String

    var summary: String {
        "\(String(format: "%.1f", overall))/10: \(specDetail.lowercased()), \(priceDetail.lowercased()), \(historyDetail.lowercased())."
    }
}

/// The transparent, rule-based value score from the proposal (not a trained model):
/// Value = 10 × (0.5·D + 0.3·P + 0.2·H)
@Observable
final class ValueScoreCalculator {
    static let shared = ValueScoreCalculator()

    static let weightD = 0.5
    static let weightP = 0.3
    static let weightH = 0.2

    var priority: ShoppingPriority = .balanced

    // Scores depend on every product in the category, so compute a category at a time and cache it
    // until prices or the shopping priority change.
    @ObservationIgnored private var cache: [UUID: ValueScore] = [:]
    @ObservationIgnored private var cacheKey = ""

    func score(for product: Product) -> ValueScore {
        let key = "\(priority.rawValue)|\(CatalogStore.shared.revision)"
        if key != cacheKey {
            cache = [:]
            cacheKey = key
        }
        if let cached = cache[product.id] { return cached }

        let peers = ProductCatalog.products(in: product.category).filter(\.isSold)
        guard product.isSold, peers.contains(product) else { return Self.neutral }
        for (id, score) in scores(for: peers) { cache[id] = score }
        return cache[product.id] ?? Self.neutral
    }

    private static let neutral = ValueScore(
        overall: 5, specificationValue: 5, pricePosition: 5, priceStability: 5,
        specDetail: "Not enough data", priceDetail: "Not currently sold", historyDetail: "No price history"
    )

    private func scores(for peers: [Product]) -> [UUID: ValueScore] {
        let specScores = normalisedSpecScores(peers)
        let prices = Dictionary(uniqueKeysWithValues: peers.map { ($0.id, $0.startingPrice) })
        let densities = peers.map { (specScores[$0.id] ?? 0.5) / max(prices[$0.id] ?? 1, 1) }.sorted()
        let median = densities[densities.count / 2]
        let average = prices.values.reduce(0, +) / Double(prices.count)

        var result: [UUID: ValueScore] = [:]
        for product in peers {
            let price = prices[product.id] ?? product.startingPrice
            let density = (specScores[product.id] ?? 0.5) / max(price, 1)
            let d = clamp(0.62 * sqrt(density / max(median, .leastNonzeroMagnitude)), 0.3, 1)
            let p = clamp(0.5 + (average - price) / average * 0.8, 0.2, 1)

            let history = product.priceHistory.map(\.price)
            let mean = history.reduce(0, +) / Double(max(history.count, 1))
            let variance = history.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(history.count, 1))
            let cv = mean > 0 ? sqrt(variance) / mean : 0
            let h = clamp(1 - cv * 7, 0.3, 1)

            let overall = 10 * (Self.weightD * d + Self.weightP * p + Self.weightH * h)
            result[product.id] = ValueScore(
                overall: (overall * 10).rounded() / 10,
                specificationValue: (d * 100).rounded() / 10,
                pricePosition: (p * 100).rounded() / 10,
                priceStability: (h * 100).rounded() / 10,
                specDetail: d >= 0.75 ? "Excellent specs for the price" : d >= 0.55 ? "Good specs for the price" : "Modest specs for the price",
                priceDetail: p >= 0.6 ? "Below the category average" : p >= 0.42 ? "Around the category average" : "Above the category average",
                historyDetail: h >= 0.8 ? "Stable price history" : h >= 0.6 ? "Some recent price movement" : "Price has moved a lot"
            )
        }
        return result
    }

    /// Weighted sum of key specs, each normalised 0.3–1 within the category.
    /// A spec a product doesn't list counts as the category median, so missing data neither helps nor hurts.
    private func normalisedSpecScores(_ peers: [Product]) -> [UUID: Double] {
        let features = features(for: peers.first?.category ?? .smartphones)
        var totals: [UUID: Double] = [:]
        var weightSum = 0.0

        for feature in features {
            let known = peers.compactMap { feature.value($0) }.sorted()
            guard let low = known.first, let high = known.last else { continue }
            let fill = known[known.count / 2]
            let weight = feature.weight * multiplier(for: feature.kind)
            weightSum += weight
            for peer in peers {
                let value = feature.value(peer) ?? fill
                let raw = high > low ? (value - low) / (high - low) : 0.5
                let normalised = 0.3 + 0.7 * (feature.higherIsBetter ? raw : 1 - raw)
                totals[peer.id, default: 0] += normalised * weight
            }
        }
        return totals.mapValues { $0 / max(weightSum, 0.0001) }
    }

    private func multiplier(for kind: SpecFeature.Kind) -> Double {
        switch (priority, kind) {
        case (.battery, .battery): return 2.2
        case (.performance, .performance): return 1.8
        case (.portability, .weight): return 2.4
        default: return 1
        }
    }

    private func features(for category: ProductCategory) -> [SpecFeature] {
        let measured: (Product, String, String) -> Double? = { product, label, unit in
            guard let text = product.specValue(for: label), text.localizedCaseInsensitiveContains(unit) else { return nil }
            return Self.number(text)
        }
        switch category {
        case .smartphones:
            return [
                SpecFeature(kind: .performance, weight: 0.35) { $0.specValue(for: "Chip").map(Self.chipTier) },
                SpecFeature(kind: .performance, weight: 0.2) { Self.gigabytes($0.specValue(for: "Storage")).map(log2) },
                SpecFeature(kind: .other, weight: 0.2) { Self.number($0.specValue(for: "Camera")) },
                SpecFeature(kind: .battery, weight: 0.25) { measured($0, "Battery", "mAh") }
            ]
        case .laptops:
            return [
                SpecFeature(kind: .performance, weight: 0.3) { $0.specValue(for: "Chip").map(Self.chipTier) },
                SpecFeature(kind: .performance, weight: 0.2) { Self.number($0.specValue(for: "Memory")) },
                SpecFeature(kind: .performance, weight: 0.15) { Self.gigabytes($0.specValue(for: "Storage")).map(log2) },
                SpecFeature(kind: .battery, weight: 0.2) { measured($0, "Battery", "Wh") },
                SpecFeature(kind: .weight, weight: 0.15, higherIsBetter: false) { measured($0, "Weight", "kg") }
            ]
        case .headphones:
            return [
                SpecFeature(kind: .battery, weight: 0.35) { measured($0, "Battery", "hour") },
                SpecFeature(kind: .weight, weight: 0.25, higherIsBetter: false) { Self.number($0.specValue(for: "Weight")) },
                SpecFeature(kind: .other, weight: 0.2) { Self.number($0.specValue(for: "Driver")) },
                SpecFeature(kind: .other, weight: 0.2) { Self.number($0.specValue(for: "Connectivity")) }
            ]
        }
    }

    /// First number in a spec value, e.g. "Up to 27 hours video" → 27.
    nonisolated static func number(_ text: String?) -> Double? {
        guard let text, let range = text.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[range])
    }

    /// "256GB" → 256, "1TB" → 1024.
    nonisolated static func gigabytes(_ text: String?) -> Double? {
        guard let value = number(text) else { return nil }
        return text?.range(of: "TB", options: .caseInsensitive) != nil ? value * 1024 : value
    }

    /// Approximate performance tier (0–10) from the chip name. A heuristic for comparing chips within
    /// a category, not a benchmark score.
    nonisolated static func chipTier(_ chip: String) -> Double {
        let chip = chip.lowercased()
        func generation(after prefix: String) -> Int? {
            guard let range = chip.range(of: prefix + #"\s?(\d+)"#, options: .regularExpression) else { return nil }
            return Int(chip[range].filter(\.isNumber))
        }

        // Apple silicon: A-series phones, M-series Macs.
        if let m = generation(after: #"\bm"#), chip.contains("apple") || chip.hasPrefix("m") {
            return min(10, 7.6 + Double(m - 1) * 0.6 + (chip.contains("pro") || chip.contains("max") ? 0.4 : 0))
        }
        if let a = generation(after: #"\ba"#), a >= 10, a <= 30 {
            return min(10, 7.6 + Double(a - 15) * 0.45 + (chip.contains("pro") ? 0.3 : 0))
        }
        // Qualcomm.
        if chip.contains("snapdragon") {
            if chip.contains("x elite") { return 9 }
            if chip.contains("x plus") { return 8.2 }
            if chip.contains("8 elite") { return 9.6 }
            if chip.contains("8 gen 3") { return 9 }
            if chip.contains("8s gen") || chip.contains("8 gen 2") { return 8.5 }
            if chip.contains("8 gen") { return 8 }
            if chip.contains("7") { return 7.1 }
            if chip.contains("6") { return 5.8 }
            if chip.contains("4") { return 4.8 }
            return 6
        }
        // MediaTek.
        if let dimensity = generation(after: "dimensity") {
            switch dimensity {
            case 9400...: return 9.4
            case 9300..<9400: return 8.8
            case 9000..<9300: return 8.3
            case 8000..<9000: return 7.5
            case 7000..<8000: return 6.5
            default: return 5.6
            }
        }
        if chip.contains("helio") { return chip.contains("g9") ? 4.8 : chip.contains("g8") ? 4.3 : 3.8 }
        // Samsung, Google, Huawei, Unisoc.
        if let exynos = generation(after: "exynos") { return exynos >= 2400 ? 8.8 : exynos >= 1300 ? 6.4 : 5.4 }
        if let tensor = generation(after: #"tensor g"#) { return min(9, 7.2 + Double(tensor - 2) * 0.5) }
        if chip.contains("kirin") { return chip.contains("9") ? 8 : 6 }
        if chip.contains("unisoc") || chip.contains("tiger") { return 3.6 }
        // Intel and AMD laptops.
        if chip.contains("ultra 9") { return 9.4 }
        if chip.contains("ultra 7") { return 8.8 }
        if chip.contains("ultra 5") { return 8 }
        if let tier = generation(after: #"\bi"#), [3, 5, 7, 9].contains(tier) {
            let bases: [Int: Double] = [3: 5.5, 5: 7.0, 7: 8.0, 9: 9.0]
            let base = bases[tier] ?? 6
            let fast = chip.contains("hx") || chip.range(of: #"\d{4,5}h\b"#, options: .regularExpression) != nil
            return min(10, base + (fast ? 0.4 : 0))
        }
        if chip.contains("core 7") { return 7.8 }
        if chip.contains("core 5") { return 7 }
        if chip.contains("core 3") { return 5.8 }
        if chip.contains("ryzen ai") { return 8.8 }
        if chip.contains("ryzen 9") { return 9 }
        if chip.contains("ryzen 7") { return 8.2 }
        if chip.contains("ryzen 5") { return 7.2 }
        if chip.contains("ryzen 3") { return 5.6 }
        if chip.contains("celeron") || chip.contains("pentium") || chip.contains("n100") || chip.contains("n200") { return 3.8 }
        return 6
    }

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(high, max(low, value))
    }
}

private struct SpecFeature {
    enum Kind { case performance, battery, weight, other }

    let kind: Kind
    let weight: Double
    var higherIsBetter = true
    let value: (Product) -> Double?

    init(kind: Kind, weight: Double, higherIsBetter: Bool = true, value: @escaping (Product) -> Double?) {
        self.kind = kind
        self.weight = weight
        self.higherIsBetter = higherIsBetter
        self.value = value
    }
}
