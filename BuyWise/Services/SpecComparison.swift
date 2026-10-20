import Foundation

/// Builds the model's input. Keep it free of app types: ml/summarizer compiles this file to make training data.
nonisolated enum SpecComparison {
    struct Fact: Codable, Equatable, Sendable {
        let label: String
        let first: String?
        let second: String?
        /// "first" or "second" when one is better, "same" for identical values, nil when they can't be ranked.
        let better: String?
        /// What the better one has, e.g. "more storage". Nil when the values can't be ranked.
        let advantage: String?
    }

    /// Facts for every spec either product lists, in the first product's spec order.
    static func facts(first: [(label: String, value: String)], second: [(label: String, value: String)]) -> [Fact] {
        var labels = first.map(\.label)
        for spec in second where !labels.contains(spec.label) { labels.append(spec.label) }
        let a = Dictionary(first.map { ($0.label, $0.value) }, uniquingKeysWith: { x, _ in x })
        let b = Dictionary(second.map { ($0.label, $0.value) }, uniquingKeysWith: { x, _ in x })
        return labels.map { fact(label: $0, a[$0], b[$0]) }
    }

    /// e.g. "compare smartphones: A: Galaxy A36 5G 128GB. B: Redmi 15 128GB. Chip: Snapdragon 6 Gen 3 | Snapdragon 685 | A faster chip. …"
    static func modelInput(category: String, firstName: String, secondName: String, facts: [Fact]) -> String {
        let lines = facts.map { fact -> String in
            let verdict: String
            switch fact.better {
            case "first": verdict = "A \(fact.advantage ?? "better")"
            case "second": verdict = "B \(fact.advantage ?? "better")"
            case "same": verdict = "same"
            default: verdict = "different"
            }
            return "\(fact.label): \(fact.first ?? "not listed") | \(fact.second ?? "not listed") | \(verdict)."
        }
        return (["compare \(category.lowercased()): A: \(firstName). B: \(secondName)."] + lines).joined(separator: " ")
    }

    // MARK: Ranking one spec

    private static func fact(label: String, _ a: String?, _ b: String?) -> Fact {
        if let a, let b, a.caseInsensitiveCompare(b) == .orderedSame {
            return Fact(label: label, first: a, second: b, better: "same", advantage: nil)
        }
        guard let rule = rules[label] else { return Fact(label: label, first: a, second: b, better: nil, advantage: nil) }
        let winner = rule(a, b)
        return Fact(label: label, first: a, second: b, better: winner?.side, advantage: winner?.advantage)
    }

    private typealias Rule = (String?, String?) -> (side: String, advantage: String)?

    private static let rules: [String: Rule] = [
        "Chip": { a, b in
            guard let a, let b else { return nil }
            let gap = SpecMath.chipTier(a) - SpecMath.chipTier(b)
            return abs(gap) < 0.3 ? nil : (gap > 0 ? "first" : "second", "a faster chip")
        },
        "Memory": higher("more memory", SpecMath.gigabytes),
        "Storage": higher("more storage", SpecMath.gigabytes),
        "Camera": higher("a higher-resolution camera", SpecMath.number),
        "Display": higher("a bigger display", SpecMath.number),
        "Driver": higher("larger drivers", SpecMath.number),
        "Connectivity": higher("newer Bluetooth", SpecMath.number),
        "Battery": { a, b in
            // Only like for like: mAh with mAh, Wh with Wh, hours with hours.
            guard let a, let b, unit(a) == unit(b), let x = SpecMath.number(a), let y = SpecMath.number(b), x != y else { return nil }
            let advantage = unit(a) == "hours" ? "longer battery life" : "a bigger battery"
            return (x > y ? "first" : "second", advantage)
        },
        "Weight": { a, b in
            guard let x = grams(a), let y = grams(b), x != y else { return nil }
            return (x < y ? "first" : "second", "a lighter build")
        },
        "5G": present("5G support"),
        "Noise Cancellation": present("active noise cancellation"),
    ]

    private static func higher(_ advantage: String, _ value: @escaping (String?) -> Double?) -> Rule {
        { a, b in
            guard let x = value(a), let y = value(b), x != y else { return nil }
            return (x > y ? "first" : "second", advantage)
        }
    }

    /// A missing spec is unknown, not "No": retailers often leave out features a product has.
    private static func present(_ advantage: String) -> Rule {
        { a, b in
            guard let a, let b else { return nil }
            let x = a.lowercased() == "yes", y = b.lowercased() == "yes"
            return x == y ? nil : (x ? "first" : "second", advantage)
        }
    }

    private static func unit(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("mah") { return "mah" }
        if lower.contains("wh") { return "wh" }
        if lower.contains("hour") { return "hours" }
        return "other"
    }

    private static func grams(_ text: String?) -> Double? {
        guard let text, let value = SpecMath.number(text) else { return nil }
        return text.lowercased().contains("kg") ? value * 1000 : value
    }
}
