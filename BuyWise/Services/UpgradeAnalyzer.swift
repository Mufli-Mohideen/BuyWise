import Foundation

struct UpgradeMetric: Identifiable {
    enum Status { case better, worse, unchanged }

    let title: String
    let unit: String
    let currentValue: Double
    let newValue: Double
    let lowerIsBetter: Bool
    /// False for values like version numbers, where a percentage change isn't meaningful.
    let showsPercent: Bool
    /// Spec label this metric was read from, if any (used to tag spec rows).
    let specLabel: String?

    var id: String { title }

    /// Raw change: ((new − current) / current) × 100.
    var changePercent: Double { (newValue - currentValue) / currentValue * 100 }

    /// Like `changePercent`, but positive always means better (flipped when lower is better).
    var improvementPercent: Double { lowerIsBetter ? -changePercent : changePercent }

    var status: Status {
        if abs(changePercent) < 0.5 { return .unchanged }
        return improvementPercent > 0 ? .better : .worse
    }

    func formatted(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(showsPercent ? 0...2 : 1...2)).grouping(.automatic))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

struct SpecComparisonRow: Identifiable {
    let label: String
    let current: String
    let new: String
    let status: UpgradeMetric.Status?

    var id: String { label }
    var isDifferent: Bool { current != new }
}

struct VersionedChange: Identifiable {
    let name: String
    let from: String
    let to: String
    var id: String { name }
}

struct FeatureChanges {
    let gained: [String]
    let lost: [String]
    let changed: [VersionedChange]
    let unchanged: [String]
}

struct PricePosition {
    let current: Double
    let average: Double
    let lowest: Double
    let highest: Double

    var percentVsAverage: Double { (current - average) / average * 100 }

    var description: String {
        let percent = percentVsAverage
        if abs(percent) <= 2 { return "close to its 90-day average" }
        return percent < 0
            ? "\(UpgradeAnalysis.percentText(abs(percent))) below its 90-day average"
            : "\(UpgradeAnalysis.percentText(percent)) above its 90-day average"
    }
}

struct CostPerImprovement: Identifiable {
    let metric: UpgradeMetric
    let costPerPercent: Double
    var id: String { metric.id }
}

struct UpgradeAnalysis {
    let current: Product
    let new: Product
    let upgradeCost: Double
    let costRetailer: Retailer
    let metrics: [UpgradeMetric]
    let specRows: [SpecComparisonRow]
    let features: FeatureChanges
    let price: PricePosition?
    let costPerImprovement: [CostPerImprovement]

    static func percentText(_ value: Double) -> String {
        abs(value) >= 10 ? "\(Int(value.rounded()))%" : String(format: "%.1f%%", value)
    }

    static func signedPercent(_ value: Double) -> String {
        (value > 0 ? "+" : value < 0 ? "−" : "") + percentText(abs(value))
    }

    /// The cost sentence, written in code so it's always exact. Starts both the Core ML and rule-based summaries.
    var costSentence: String {
        "Upgrading from the \(current.fullName) to the \(new.fullName) costs \(PriceFormatter.lkr(upgradeCost)) at \(costRetailer.rawValue)."
    }

    /// Feature and price-trend sentences, written in code. Ends both the Core ML and rule-based summaries.
    var closingSentences: [String] {
        var sentences: [String] = []
        let additions = features.gained + features.changed.map { "\($0.name) \($0.to) (was \($0.from))" }
        if !additions.isEmpty {
            let shown = Array(additions.prefix(3))
            let extra = additions.count - shown.count
            let text = extra > 0
                ? shown.joined(separator: ", ") + " and \(extra) other change\(extra == 1 ? "" : "s")"
                : shown.joinedAsList()
            sentences.append("The new model adds \(text).")
        }
        if !features.lost.isEmpty {
            sentences.append("It no longer has \(features.lost.joinedAsList()).")
        }
        if let price {
            sentences.append("The current price is \(price.description).")
        }
        return sentences
    }

    /// Rule-based fallback for when the Core ML model can't run. Only describes the data and never recommends.
    var summary: String {
        var sentences: [String] = [costSentence]

        let better = metrics.filter { $0.status == .better && $0.showsPercent }.sorted { $0.improvementPercent > $1.improvementPercent }
        if !better.isEmpty {
            let parts = better.prefix(3).map { metric -> String in
                let direction = metric.lowerIsBetter ? "lower" : "higher"
                return "\(metric.title.lowercased()) is approximately \(Self.percentText(abs(metric.changePercent))) \(direction)"
            }
            sentences.append(Self.sentenceCase(parts.joinedAsList()) + ".")
        }

        let worse = metrics.filter { $0.status == .worse && $0.showsPercent }
        if !worse.isEmpty {
            let parts = worse.map { metric -> String in
                let direction = metric.changePercent > 0 ? "higher" : "lower"
                return "\(metric.title.lowercased()) is approximately \(Self.percentText(abs(metric.changePercent))) \(direction)"
            }
            sentences.append("On the other hand, \(parts.joinedAsList()).")
        }

        for metric in metrics where !metric.showsPercent && metric.status != .unchanged {
            sentences.append("\(metric.title) goes from \(metric.formatted(metric.currentValue)) to \(metric.formatted(metric.newValue)).")
        }

        let unchanged = metrics.filter { $0.status == .unchanged }
        if !unchanged.isEmpty {
            sentences.append("\(Self.sentenceCase(unchanged.map { $0.title.lowercased() }.joinedAsList())) \(unchanged.count == 1 ? "is" : "are") unchanged.")
        }

        return (sentences + closingSentences).joined(separator: " ")
    }

    private static func sentenceCase(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// Compares a product the user owns with one they are considering, using existing catalogue data.
enum UpgradeAnalyzer {
    private struct MetricDefinition {
        let title: String
        let unit: String
        var lowerIsBetter = false
        var showsPercent = true
        var specLabel: String? = nil
        let value: (Product) -> Double?
    }

    static func analyze(current: Product, new: Product) -> UpgradeAnalysis {
        let metrics: [UpgradeMetric] = definitions(for: new.category).compactMap { definition in
            guard let a = definition.value(current), let b = definition.value(new), a > 0, b > 0 else { return nil }
            return UpgradeMetric(title: definition.title, unit: definition.unit, currentValue: a, newValue: b,
                                 lowerIsBetter: definition.lowerIsBetter, showsPercent: definition.showsPercent,
                                 specLabel: definition.specLabel)
        }

        let labels = current.specifications.map(\.label) + new.specifications.map(\.label).filter { label in
            !current.specifications.contains { $0.label == label }
        }
        let specRows = labels.map { label in
            SpecComparisonRow(
                label: label,
                current: current.specValue(for: label) ?? "—",
                new: new.specValue(for: label) ?? "—",
                status: metrics.first { $0.specLabel == label }?.status
            )
        }

        let lowest = new.lowestListing
        let price = pricePosition(for: new)
        let costs = metrics
            // Only where the gain is large enough for "cost per 1%" to mean something.
            .filter { $0.showsPercent && $0.improvementPercent >= 5 }
            .map { CostPerImprovement(metric: $0, costPerPercent: lowest.price / $0.improvementPercent) }

        return UpgradeAnalysis(
            current: current,
            new: new,
            upgradeCost: lowest.price,
            costRetailer: lowest.retailer,
            metrics: metrics,
            specRows: specRows,
            features: featureChanges(current: current, new: new),
            price: price,
            costPerImprovement: costs
        )
    }

    private static func definitions(for category: ProductCategory) -> [MetricDefinition] {
        let spec: (String) -> (Product) -> Double? = { label in { SpecMath.number($0.specValue(for: label)) } }
        // Only compare a measurement when both products state it in the same unit (e.g. mAh, not hours).
        let measured: (String, String) -> (Product) -> Double? = { label, unit in
            { product in
                guard let text = product.specValue(for: label), text.localizedCaseInsensitiveContains(unit) else { return nil }
                return SpecMath.number(text)
            }
        }
        let storage: (Product) -> Double? = { SpecMath.gigabytes($0.specValue(for: "Storage")) }
        let chipTier = MetricDefinition(title: "Chip tier (est.)", unit: "/10", specLabel: "Chip") {
            $0.specValue(for: "Chip").map(SpecMath.chipTier)
        }

        switch category {
        case .smartphones:
            return [
                chipTier,
                MetricDefinition(title: "Main camera", unit: "MP", specLabel: "Camera", value: spec("Camera")),
                MetricDefinition(title: "Battery capacity", unit: "mAh", specLabel: "Battery", value: measured("Battery", "mAh")),
                MetricDefinition(title: "Memory", unit: "GB", specLabel: "Memory", value: spec("Memory")),
                MetricDefinition(title: "Storage", unit: "GB", specLabel: "Storage", value: storage)
            ]
        case .laptops:
            return [
                chipTier,
                MetricDefinition(title: "Memory", unit: "GB", specLabel: "Memory", value: spec("Memory")),
                MetricDefinition(title: "Storage", unit: "GB", specLabel: "Storage", value: storage),
                MetricDefinition(title: "Battery capacity", unit: "Wh", specLabel: "Battery", value: measured("Battery", "Wh")),
                MetricDefinition(title: "Weight", unit: "kg", lowerIsBetter: true, specLabel: "Weight", value: measured("Weight", "kg"))
            ]
        case .headphones:
            return [
                MetricDefinition(title: "Battery life", unit: "h", specLabel: "Battery", value: measured("Battery", "hour")),
                MetricDefinition(title: "Weight", unit: "g", lowerIsBetter: true, specLabel: "Weight", value: spec("Weight")),
                MetricDefinition(title: "Bluetooth version", unit: "", showsPercent: false, specLabel: "Connectivity", value: spec("Connectivity"))
            ]
        }
    }

    private static func featureChanges(current: Product, new: Product) -> FeatureChanges {
        // Only the bundled reference devices have feature lists, so skip this unless both products have one.
        guard let currentEntry = UpgradeReferenceData.entry(for: current), let newEntry = UpgradeReferenceData.entry(for: new) else {
            return FeatureChanges(gained: [], lost: [], changed: [], unchanged: [])
        }

        let oldSet = Set(currentEntry.features)
        let newSet = Set(newEntry.features)
        var gained = newEntry.features.filter { !oldSet.contains($0) }
        var lost = currentEntry.features.filter { !newSet.contains($0) }
        let unchanged = newEntry.features.filter { oldSet.contains($0) }

        var changed: [VersionedChange] = []
        for key in (Array(currentEntry.versioned.keys) + newEntry.versioned.keys.filter { currentEntry.versioned[$0] == nil }).sorted() {
            switch (currentEntry.versioned[key], newEntry.versioned[key]) {
            case let (from?, to?) where from != to: changed.append(VersionedChange(name: key, from: from, to: to))
            case (nil, let to?): gained.append("\(key) \(to)")
            case (let from?, nil): lost.append("\(key) \(from)")
            default: break
            }
        }
        return FeatureChanges(gained: gained, lost: lost, changed: changed, unchanged: unchanged)
    }

    private static func pricePosition(for product: Product) -> PricePosition? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let prices = product.priceHistory.filter { $0.date >= cutoff }.map(\.price)
        guard !prices.isEmpty else { return nil }
        return PricePosition(
            current: product.startingPrice,
            average: prices.reduce(0, +) / Double(prices.count),
            lowest: prices.min() ?? product.startingPrice,
            highest: prices.max() ?? product.startingPrice
        )
    }
}
