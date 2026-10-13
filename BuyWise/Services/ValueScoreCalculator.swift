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

    func score(for product: Product) -> ValueScore {
        let peers = ProductCatalog.all.filter { $0.category == product.category }
        let specScores = normalisedSpecScores(peers)
        let prices = Dictionary(uniqueKeysWithValues: peers.map { ($0.id, $0.startingPrice) })

        let densities = peers.map { (specScores[$0.id] ?? 0.5) / max(prices[$0.id] ?? 1, 1) }
        let median = densities.sorted()[densities.count / 2]
        let price = prices[product.id] ?? product.startingPrice
        let density = (specScores[product.id] ?? 0.5) / max(price, 1)
        let d = clamp(0.62 * sqrt(density / max(median, .leastNonzeroMagnitude)), 0.3, 1)

        let average = prices.values.reduce(0, +) / Double(prices.count)
        let p = clamp(0.5 + (average - price) / average * 0.8, 0.2, 1)

        let history = product.priceHistory.map(\.price)
        let mean = history.reduce(0, +) / Double(max(history.count, 1))
        let variance = history.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(history.count, 1))
        let cv = mean > 0 ? sqrt(variance) / mean : 0
        let h = clamp(1 - cv * 7, 0.3, 1)

        let overall = 10 * (Self.weightD * d + Self.weightP * p + Self.weightH * h)

        return ValueScore(
            overall: (overall * 10).rounded() / 10,
            specificationValue: (d * 100).rounded() / 10,
            pricePosition: (p * 100).rounded() / 10,
            priceStability: (h * 100).rounded() / 10,
            specDetail: d >= 0.75 ? "Excellent specs for the price" : d >= 0.55 ? "Good specs for the price" : "Modest specs for the price",
            priceDetail: p >= 0.6 ? "Below the category average" : p >= 0.42 ? "Around the category average" : "Above the category average",
            historyDetail: h >= 0.8 ? "Stable price history" : h >= 0.6 ? "Some recent price movement" : "Price has moved a lot"
        )
    }

    /// Weighted sum of key specs, each normalised 0.3–1 within the category.
    private func normalisedSpecScores(_ peers: [Product]) -> [UUID: Double] {
        let features = features(for: peers.first?.category ?? .smartphones)
        var totals: [UUID: Double] = [:]
        var weightSum = 0.0

        for feature in features {
            let weight = feature.weight * multiplier(for: feature.kind)
            weightSum += weight
            let values = peers.map { feature.value($0) }
            guard let low = values.min(), let high = values.max() else { continue }
            for (peer, value) in zip(peers, values) {
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
        switch category {
        case .smartphones:
            return [
                SpecFeature(kind: .performance, weight: 0.35) { Self.chipTier($0.specValue(for: "Chip")) },
                SpecFeature(kind: .performance, weight: 0.2) { log2(Self.number($0.specValue(for: "Storage")) ?? 128) },
                SpecFeature(kind: .other, weight: 0.2) { Self.number($0.specValue(for: "Camera")) ?? 12 },
                SpecFeature(kind: .battery, weight: 0.25) { Self.number($0.specValue(for: "Battery")) ?? 20 }
            ]
        case .laptops:
            return [
                SpecFeature(kind: .performance, weight: 0.3) { Self.chipTier($0.specValue(for: "Chip")) },
                SpecFeature(kind: .performance, weight: 0.2) { Self.number($0.specValue(for: "Memory")) ?? 8 },
                SpecFeature(kind: .performance, weight: 0.15) { log2(Self.number($0.specValue(for: "Storage")) ?? 256) },
                SpecFeature(kind: .battery, weight: 0.2) { Self.number($0.specValue(for: "Battery")) ?? 8 },
                SpecFeature(kind: .weight, weight: 0.15, higherIsBetter: false) { Self.number($0.specValue(for: "Weight")) ?? 1.5 }
            ]
        case .headphones:
            return [
                SpecFeature(kind: .battery, weight: 0.35) { Self.number($0.specValue(for: "Battery")) ?? 20 },
                SpecFeature(kind: .weight, weight: 0.25, higherIsBetter: false) { Self.number($0.specValue(for: "Weight")) ?? 250 },
                SpecFeature(kind: .other, weight: 0.2) { Self.number($0.specValue(for: "Driver")) ?? 30 },
                SpecFeature(kind: .other, weight: 0.2) { Self.number($0.specValue(for: "Connectivity")) ?? 5 }
            ]
        }
    }

    /// First number in a spec value, e.g. "Up to 27 hours video" → 27.
    static func number(_ text: String?) -> Double? {
        guard let text, let range = text.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[range])
    }

    private static func chipTier(_ chip: String?) -> Double {
        let chip = chip?.lowercased() ?? ""
        let tiers: [(String, Double)] = [
            ("a18 pro", 10), ("snapdragon 8 elite", 9.5), ("dimensity 9300", 8.8), ("tensor g4", 8.0),
            ("apple m3", 10), ("i5-1335u", 7.5), ("i5-1235u", 7.0), ("ryzen 5 7530u", 7.0)
        ]
        return tiers.first { chip.contains($0.0) }?.1 ?? 6
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
    let value: (Product) -> Double

    init(kind: Kind, weight: Double, higherIsBetter: Bool = true, value: @escaping (Product) -> Double) {
        self.kind = kind
        self.weight = weight
        self.higherIsBetter = higherIsBetter
        self.value = value
    }
}
