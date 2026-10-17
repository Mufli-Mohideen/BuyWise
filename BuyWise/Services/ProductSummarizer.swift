import Foundation
import FoundationModels

/// Short, neutral comparison summaries. The price sentence is computed in code; Apple's on-device language
/// model (Apple Intelligence) describes the specification differences. Devices without Apple Intelligence
/// get a rule-based summary built from the same facts.
enum ProductSummarizer {
    enum Source: Equatable {
        case onDeviceModel
        case rules
    }

    struct Summary: Equatable {
        let text: String
        let source: Source
    }

    // The model only writes about specifications. Prices are stated by `priceSentence`, computed in code,
    // because small on-device models are unreliable at arithmetic and a summary must never misstate a price.
    private static let instructions = """
        You describe how two products differ for a Sri Lankan shopping app. You are given specifications \
        that both products list. Write one or two plain sentences about the most important differences. \
        Use only the values given and refer to each product by its name. Do not mention prices, do not say \
        which one to buy, and do not use lists, headings or marketing language.
        """

    static func compare(_ first: Product, _ second: Product) async -> Summary {
        let price = priceSentence(first, second)
        let fallback = Summary(text: ruleBasedComparison(first, second), source: .rules)
        let shared = sharedSpecs(first, second)
        guard SystemLanguageModel.default.isAvailable, !shared.isEmpty else { return fallback }

        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: "\(first.fullName) vs \(second.fullName):\n" + shared.joined(separator: "\n"),
                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 120)
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return fallback }
            return Summary(text: [price, text].compactMap { $0 }.joined(separator: " "), source: .onDeviceModel)
        } catch {
            return fallback
        }
    }

    /// "Storage: Galaxy S25 FE 256GB = 256GB, Redmi Note 15 128GB = 128GB" for each spec both products list.
    private static func sharedSpecs(_ first: Product, _ second: Product) -> [String] {
        first.specifications.compactMap { spec in
            guard let other = second.specValue(for: spec.label), other != spec.value else { return nil }
            return "\(spec.label): \(first.name) = \(spec.value), \(second.name) = \(other)"
        }
    }

    /// Deterministic price comparison, e.g. "The vivo Y04 is LKR 15,000 cheaper, at LKR 29,999 from Abans."
    static func priceSentence(_ first: Product, _ second: Product) -> String? {
        guard first.isSold, second.isSold else { return nil }
        let (cheaper, pricier) = first.startingPrice <= second.startingPrice ? (first, second) : (second, first)
        let gap = pricier.startingPrice - cheaper.startingPrice
        return gap > 0
            ? "The \(cheaper.name) is \(PriceFormatter.lkr(gap)) cheaper, at \(PriceFormatter.lkr(cheaper.startingPrice)) from \(cheaper.lowestListing.retailer.rawValue)."
            : "Both cost \(PriceFormatter.lkr(first.startingPrice)) at their cheapest."
    }

    // MARK: Rule-based fallback

    private struct Measure {
        let label: String
        let noun: String
        var lowerIsBetter = false
        let value: (Product) -> Double?
    }

    private static let measures: [Measure] = [
        Measure(label: "Chip", noun: "faster chip") { $0.specValue(for: "Chip").map(ValueScoreCalculator.chipTier) },
        Measure(label: "Memory", noun: "more memory") { ValueScoreCalculator.number($0.specValue(for: "Memory")) },
        Measure(label: "Storage", noun: "more storage") { ValueScoreCalculator.gigabytes($0.specValue(for: "Storage")) },
        Measure(label: "Camera", noun: "a higher-resolution camera") { ValueScoreCalculator.number($0.specValue(for: "Camera")) },
        Measure(label: "Battery", noun: "a bigger battery") { ValueScoreCalculator.number($0.specValue(for: "Battery")) },
        Measure(label: "Weight", noun: "a lighter build", lowerIsBetter: true) { ValueScoreCalculator.number($0.specValue(for: "Weight")) },
    ]

    static func ruleBasedComparison(_ first: Product, _ second: Product) -> String {
        var sentences: [String] = priceSentence(first, second).map { [$0] } ?? []

        var advantages: [Product: [String]] = [:]
        for measure in measures {
            guard let a = measure.value(first), let b = measure.value(second), a != b else { continue }
            if measure.label == "Battery",
               unit(of: first.specValue(for: "Battery")) != unit(of: second.specValue(for: "Battery")) { continue }
            let firstWins = measure.lowerIsBetter ? a < b : a > b
            advantages[firstWins ? first : second, default: []].append(measure.noun)
        }
        for product in [first, second] {
            if let wins = advantages[product], !wins.isEmpty {
                sentences.append("The \(product.name) has \(list(Array(wins.prefix(3)))).")
            }
        }
        if advantages.isEmpty {
            sentences.append("Their listed specifications are similar, so price is the main difference.")
        }
        return sentences.joined(separator: " ")
    }

    /// "5000 mAh" → "mah", "Up to 30 hours" → "hours", so batteries are only compared like for like.
    private static func unit(of text: String?) -> String? {
        guard let text else { return nil }
        let words = text.lowercased()
            .replacingOccurrences(of: #"[\d.,\s"]+"#, with: " ", options: .regularExpression)
            .components(separatedBy: " ")
        return words.last { !$0.isEmpty && $0.count <= 5 && $0.allSatisfy(\.isLetter) }
    }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }
}
