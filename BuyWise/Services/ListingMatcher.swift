import Foundation
import NaturalLanguage

struct ListingComparison: Hashable {
    let similarity: Double
    let confidence: Double
    let modelMatched: Bool
    let storageMatched: Bool
    let variantMatched: Bool
    let conflictReason: String?

    var isMatch: Bool { conflictReason == nil && modelMatched && confidence >= 0.6 }
}

struct RetailerTitle: Hashable {
    let retailer: Retailer
    let title: String
}

struct ListingMatch: Hashable {
    /// One listing title per retailer selling the product, in `Retailer.allCases` order.
    let titles: [RetailerTitle]
    /// The lowest match against the first title, so a single mismatched store still shows up.
    let comparison: ListingComparison
}

/// Checks if two listings are the same product using text similarity and model, storage and variant rules.
final class ListingMatcher {
    static let shared = ListingMatcher()

    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private var comparisonCache: [String: ListingComparison] = [:]
    private var matchCache: [UUID: ListingMatch] = [:]

    func match(for product: Product) -> ListingMatch {
        if let cached = matchCache[product.id] { return cached }

        var titles = Retailer.allCases.compactMap { retailer in
            product.listing(for: retailer).map { RetailerTitle(retailer: retailer, title: $0.title) }
        }
        if titles.isEmpty {
            titles = [RetailerTitle(retailer: .celltronics, title: product.fullName)]
        }
        let reference = titles[0].title
        let comparison = titles.count > 1
            ? titles.dropFirst().map { compare(reference, $0.title) }.min { $0.confidence < $1.confidence }!
            : compare(reference, product.fullName)

        let match = ListingMatch(titles: titles, comparison: comparison)
        matchCache[product.id] = match
        return match
    }

    func compare(_ first: String, _ second: String) -> ListingComparison {
        let key = "\(first)|\(second)"
        if let cached = comparisonCache[key] { return cached }

        let a = ParsedListing(first)
        let b = ParsedListing(second)

        let similarity = semanticSimilarity(a.cleaned, b.cleaned, fallbackA: a.allTokens, fallbackB: b.allTokens)

        var conflict: String?
        var storageMatched = true
        var variantMatched = true

        if let sa = a.storage, let sb = b.storage, sa != sb {
            storageMatched = false
            conflict = "Different storage (\(ParsedListing.format(gb: sb)) vs \(ParsedListing.format(gb: sa)))"
        }
        if conflict == nil, let za = a.screenSize, let zb = b.screenSize, za != zb {
            variantMatched = false
            conflict = "Different screen size (\(ParsedListing.format(inches: zb)) vs \(ParsedListing.format(inches: za)))"
        }
        if conflict == nil, let generation = ParsedListing.generationConflict(a, b) {
            conflict = "Different model (\(generation.1) vs \(generation.0))"
        }
        if conflict == nil, let series = ParsedListing.seriesConflict(a, b) {
            conflict = "Different model (\(series.1) vs \(series.0))"
        }
        if conflict == nil, a.tiers != b.tiers {
            variantMatched = false
            let describe: (Set<String>) -> String = { $0.isEmpty ? "standard" : ParsedListing.orderedTiers($0) }
            conflict = "Different variant (\(describe(b.tiers)) vs \(describe(a.tiers)))"
        }
        if conflict == nil, !a.lineWords.isEmpty, !b.lineWords.isEmpty, a.lineWords.isDisjoint(with: b.lineWords) {
            let describe: (Set<String>) -> String = { $0.sorted().map(\.capitalized).joined(separator: " ") }
            conflict = "Different model (\(describe(b.lineWords)) vs \(describe(a.lineWords)))"
        }

        let sharedModelTokens = !a.modelTokens.isDisjoint(with: b.modelTokens)
        let lineOverlap = ParsedListing.jaccard(a.lineWords, b.lineWords)
        let modelMatched = conflict?.hasPrefix("Different model") != true
            && (sharedModelTokens || (a.modelTokens.isEmpty && b.modelTokens.isEmpty && lineOverlap >= 0.6))

        let confidence: Double
        if conflict == nil {
            confidence = 0.55 * similarity + 0.45 * (modelMatched ? 1 : 0)
        } else {
            confidence = min(similarity * 0.5, 0.45)
        }

        let result = ListingComparison(
            similarity: similarity,
            confidence: confidence,
            modelMatched: modelMatched,
            storageMatched: storageMatched,
            variantMatched: variantMatched,
            conflictReason: conflict
        )
        comparisonCache[key] = result
        return result
    }

    private func semanticSimilarity(_ a: String, _ b: String, fallbackA: Set<String>, fallbackB: Set<String>) -> Double {
        if a == b { return 1 }
        if let embedding {
            let distance = embedding.distance(between: a, and: b, distanceType: .cosine)
            if distance.isFinite {
                return max(0, min(1, 1 - distance))
            }
        }
        return ParsedListing.jaccard(fallbackA, fallbackB)
    }
}

/// A listing title split into the parts the matcher compares.
struct ParsedListing {
    let cleaned: String
    let allTokens: Set<String>
    let modelTokens: Set<String>
    let lineWords: Set<String>
    let tiers: Set<String>
    let storage: Int?
    let screenSize: Double?
    /// Product-line word → series number, e.g. "slim" → "5", "pixel" → "9".
    let seriesNumbers: [String: String]

    private static let brands: Set<String> = ["apple", "samsung", "google", "xiaomi", "asus", "lenovo", "hp", "sony", "bose", "jbl"]
    private static let tierWords: Set<String> = ["pro", "max", "ultra", "plus", "mini", "lite", "fe", "edge"]
    private static let fillers: Set<String> = [
        "wireless", "noise", "cancelling", "canceling", "cancellation", "nc", "adaptive", "headphones", "headphone",
        "over", "ear", "overear", "5g", "chip", "ssd", "inch", "the", "with", "new", "gen", "core", "ryzen", "intel",
        "amd", "usb", "c", "usbc", "ram", "unified", "memory", "and", "smartphone", "laptop", "phone"
    ]
    private static let colours: Set<String> = [
        "black", "white", "midnight", "starlight", "silver", "blue", "icy", "icyblue", "peony", "titanium", "natural",
        "gray", "grey", "titan", "obsidian", "marble", "pink", "green", "purple", "orange"
    ]
    private static let aliases: [String: String] = ["qc": "quietcomfort"]

    init(_ title: String) {
        let lower = title.lowercased()

        let gbValues = ParsedListing.matches(in: lower, pattern: #"(\d+)\s*(gb|tb)"#).compactMap { groups -> Int? in
            guard let value = Int(groups[0]) else { return nil }
            return groups[1] == "tb" ? value * 1024 : value
        }
        storage = gbValues.max()

        screenSize = ParsedListing.matches(in: lower, pattern: #"(\d{2}(?:\.\d)?)\s*(?:"|-inch|inch)"#)
            .compactMap { Double($0[0]) }
            .first

        let working = lower
            .replacingOccurrences(of: #"(\d+)\s*(gb|tb)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\d{2}(?:\.\d)?\s*(?:"|-inch|inch)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\d+(st|nd|rd|th)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[()/,"'+:]"#, with: " ", options: .regularExpression)

        var tokens: [String] = []
        for raw in working.split(whereSeparator: { $0 == " " }) {
            let piece = String(raw)
            if piece == "-" { continue }
            let parts = piece.split(separator: "-").map(String.init).filter { !$0.isEmpty }
            if parts.count > 1 {
                tokens.append(parts.joined())
                tokens.append(contentsOf: parts)
            } else if let only = parts.first {
                tokens.append(only)
            }
        }
        tokens = tokens.map { ParsedListing.aliases[$0] ?? $0 }

        let tokenSet = Set(tokens)
        allTokens = tokenSet.subtracting(ParsedListing.fillers)
        modelTokens = Set(tokens.filter { token in
            token.rangeOfCharacter(from: .decimalDigits) != nil && token != "5g"
        })
        tiers = tokenSet.intersection(ParsedListing.tierWords)
        lineWords = Set(tokens.filter { token in
            token.rangeOfCharacter(from: .decimalDigits) == nil
                && !ParsedListing.brands.contains(token)
                && !ParsedListing.fillers.contains(token)
                && !ParsedListing.colours.contains(token)
                && !ParsedListing.tierWords.contains(token)
                && token.count > 1
        })

        var series: [String: String] = [:]
        for (index, token) in tokens.enumerated() where index + 1 < tokens.count {
            let next = tokens[index + 1]
            let isWord = token.rangeOfCharacter(from: .decimalDigits) == nil
                && !ParsedListing.brands.contains(token)
                && !ParsedListing.fillers.contains(token)
                && !ParsedListing.tierWords.contains(token)
            if isWord, !next.isEmpty, next.allSatisfy(\.isNumber) {
                series[token] = next
            }
        }
        seriesNumbers = series

        let orderedCore = tokens.filter { !ParsedListing.fillers.contains($0) && !ParsedListing.colours.contains($0) }
        var seen = Set<String>()
        cleaned = orderedCore.filter { seen.insert($0).inserted }.joined(separator: " ")
    }

    /// Two tokens with the same letter prefix but different trailing number (XM4 vs XM5, M2 vs M3, S24 vs S25).
    static func generationConflict(_ a: ParsedListing, _ b: ParsedListing) -> (String, String)? {
        let split: (String) -> (String, String)? = { token in
            guard let groups = matches(in: token, pattern: #"^(.*[a-z])(\d+)$"#).first, groups.count == 2 else { return nil }
            return (groups[0], groups[1])
        }
        for ta in a.modelTokens {
            guard let (pa, na) = split(ta) else { continue }
            for tb in b.modelTokens {
                guard let (pb, nb) = split(tb), pa == pb, na != nb else { continue }
                if !b.modelTokens.contains(ta) && !a.modelTokens.contains(tb) {
                    return (ta.uppercased(), tb.uppercased())
                }
            }
        }
        return nil
    }

    /// Same product line with a different series number (IdeaPad Slim 3 vs Slim 5).
    static func seriesConflict(_ a: ParsedListing, _ b: ParsedListing) -> (String, String)? {
        for (word, number) in a.seriesNumbers {
            if let other = b.seriesNumbers[word], other != number {
                return ("\(word.capitalized) \(number)", "\(word.capitalized) \(other)")
            }
        }
        return nil
    }

    static func orderedTiers(_ tiers: Set<String>) -> String {
        let order = ["pro", "max", "ultra", "plus", "mini", "lite", "fe", "edge"]
        return order.filter(tiers.contains).map(\.capitalized).joined(separator: " ")
    }

    static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }

    static func format(gb: Int) -> String {
        gb >= 1024 ? "\(gb / 1024)TB" : "\(gb)GB"
    }

    static func format(inches: Double) -> String {
        inches == inches.rounded() ? "\(Int(inches))\"" : "\(inches)\""
    }

    private static func matches(in text: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { result in
            (1..<result.numberOfRanges).compactMap { index in
                Range(result.range(at: index), in: text).map { String(text[$0]) }
            }
        }
    }
}
