import Foundation

/// Short, neutral comparison summaries. The price sentence is computed in code; a T5-small model fine-tuned
/// for BuyWise (ml/summarizer) and run with Core ML describes the specification differences. If the model
/// can't run, or writes a number that isn't in the specs, a rule-based summary of the same facts is used.
enum ProductSummarizer {
    enum Source: Equatable {
        case coreML
        case rules
    }

    struct Summary: Equatable {
        let text: String
        let source: Source
    }

    static func compare(_ first: Product, _ second: Product) async -> Summary {
        guard let written = await specSummary(first, second) else {
            return Summary(text: ruleBasedComparison(first, second), source: .rules)
        }
        return Summary(text: [priceSentence(first, second), written].compactMap { $0 }.joined(separator: " "), source: .coreML)
    }

    /// Upgrade analysis: the cost, feature and price sentences come from code; the Core ML model describes how
    /// the device you own and the one you're considering differ.
    static func upgrade(_ analysis: UpgradeAnalysis) async -> Summary {
        guard let written = await specSummary(analysis.current, analysis.new) else {
            return Summary(text: analysis.summary, source: .rules)
        }
        return Summary(text: ([analysis.costSentence, written] + analysis.closingSentences).joined(separator: " "), source: .coreML)
    }

    /// The model's description of the spec differences, or nil if it can't run or writes something unsupported.
    private static func specSummary(_ first: Product, _ second: Product) async -> String? {
        let facts = comparisonFacts(first, second)
        let input = SpecComparison.modelInput(category: first.category.rawValue, firstName: first.name, secondName: second.name, facts: facts)
        // Off the main thread: the decoder runs once per word piece.
        let written = await Task.detached(priority: .userInitiated) {
            try? T5Summarizer.shared?.summarize(input)
        }.value
        guard let written, isFaithful(written, input: input, facts: facts, first: first.name, second: second.name) else { return nil }
        return written
    }

    /// The spec-by-spec comparison the model reads, built by the same code that made its training data.
    private static func comparisonFacts(_ first: Product, _ second: Product) -> [SpecComparison.Fact] {
        SpecComparison.facts(
            first: first.specifications.map { ($0.label, $0.value) },
            second: second.specifications.map { ($0.label, $0.value) }
        )
    }

    /// How each advantage reads in a summary, e.g. "a bigger 5000 mAh battery" states "a bigger battery".
    private static let advantageWording: [(advantage: String, pattern: String)] = [
        ("a faster chip", "faster chip"), ("more memory", "more memory"), ("more storage", "more storage"),
        ("a higher-resolution camera", "higher-resolution"), ("a bigger battery", #"bigger [\d.,]* ?(mAh |Wh )?battery"#),
        ("longer battery life", "longer battery life"), ("a bigger display", #"bigger [\d.]*-?(inch )?display"#),
        ("a lighter build", "lighter build"), ("5G support", "5G support"), ("active noise cancellation", "noise cancellation"),
        ("larger drivers", "drivers"), ("newer Bluetooth", "newer Bluetooth"),
    ]

    /// Guards against a model mistake reaching the user. Every number must come from the specs, and every
    /// advantage the summary states must be true of the product it names. A summary that states no advantage
    /// at all must say the products are similar.
    private static func isFaithful(_ text: String, input: String, facts: [SpecComparison.Fact], first: String, second: String) -> Bool {
        guard !text.isEmpty else { return false }
        let numbers = text.matches(of: /\d+(?:\.\d+)?/).map { String($0.output) }
        guard numbers.allSatisfy(input.contains) else { return false }

        let truth = Set(facts.compactMap { fact in fact.advantage.map { "\(fact.better ?? ""):\($0)" } })
        var claims: Set<String> = []
        for wording in advantageWording {
            for match in text.ranges(of: try! Regex(wording.pattern)) {
                guard let side = owner(of: match.lowerBound, in: text, first: first, second: second) else { return false }
                let claim = "\(side):\(wording.advantage)"
                // A false claim, or the same claim twice ("a lighter build … and a lighter build").
                guard truth.contains(claim), claims.insert(claim).inserted else { return false }
            }
        }
        return !claims.isEmpty || text.localizedCaseInsensitiveContains("similar")
    }

    /// The product named most recently before `position`; the longer name wins when one contains the other
    /// ("iPhone 13 128GB" vs "iPhone 13").
    private static func owner(of position: String.Index, in text: String, first: String, second: String) -> String? {
        let before = text[..<position]
        let candidates = [("first", first), ("second", second)].compactMap { side, name in
            before.ranges(of: name).last.map { (side: side, start: $0.lowerBound, length: name.count) }
        }
        return candidates.max { ($0.start, $0.length) < ($1.start, $1.length) }?.side
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
