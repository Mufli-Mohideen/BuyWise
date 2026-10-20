import Foundation
import Supabase

struct IdentificationResult {
    let product: Product
    let confidence: Double
    let method: Method
    let evidence: String

    enum Method: String {
        case text = "Text recognised"
        case barcode = "Barcode"
        case url = "Retailer link"
        case name = "Product name"
    }
}

enum IdentificationError: LocalizedError {
    case unsupportedRetailer
    case notFound
    case noTextFound
    case noBarcodeFound
    case offline

    var errorDescription: String? {
        switch self {
        case .unsupportedRetailer: return "Only Celltronics, Abans and Singer product links are supported."
        case .notFound: return "We couldn't match this to a product in the catalogue."
        case .noTextFound: return "No readable text was found in this image."
        case .noBarcodeFound: return "No barcode was found in this image."
        case .offline: return "Couldn't reach BuyWise. Check your connection and try again."
        }
    }
}

/// The backend narrows the candidates; the on-device listing matcher makes the final call on free text.
enum ProductIdentifier {
    static func identify(text: String, method: IdentificationResult.Method) async throws -> IdentificationResult {
        let query = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { throw IdentificationError.noTextFound }

        let candidates: [ProductRow] = try await backend {
            try await supabase.rpc("search_products", params: SearchParams(query: query, maxResults: 8)).execute().value
        }

        // A photo of a web page or box has many unrelated words, which drags down the similarity to a short
        // product name. So the rules are checked against all the text, and similarity is also scored per line.
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 4 }
        let passages = [query] + (lines.count > 1 ? lines : [])

        var best: (Product, Double)?
        for row in candidates {
            guard let product = ProductCatalog.product(id: row.id) else { continue }
            let score = ([product.fullName] + product.listings.map(\.title))
                .map { name in matchConfidence(of: name, query: query, passages: passages) }
                .max() ?? 0
            if score > (best?.1 ?? 0) {
                best = (product, score)
            }
        }

        guard let (product, confidence) = best, confidence >= 0.55 else { throw IdentificationError.notFound }
        return IdentificationResult(product: product, confidence: confidence, method: method, evidence: text)
    }

    /// Zero when the full text conflicts with the name (different storage, model or variant); otherwise the
    /// best confidence from the full text or any single line.
    private static func matchConfidence(of name: String, query: String, passages: [String]) -> Double {
        let full = ListingMatcher.shared.compare(query, name)
        guard full.conflictReason == nil, full.modelMatched else { return 0 }
        return passages
            .map { ListingMatcher.shared.compare($0, name) }
            .filter { $0.conflictReason == nil && $0.modelMatched }
            .map(\.confidence)
            .max() ?? 0
    }

    static func identify(barcode: String) async throws -> IdentificationResult {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw IdentificationError.noBarcodeFound }
        let rows: [ProductRow] = try await backend {
            try await supabase.rpc("find_product_by_barcode", params: BarcodeParams(code: code)).execute().value
        }
        guard let row = rows.first, let product = ProductCatalog.product(id: row.id) else { throw IdentificationError.notFound }
        return IdentificationResult(product: product, confidence: 1, method: .barcode, evidence: code)
    }

    /// Celltronics (celltronics.lk), Abans (buyabans.com) and Singer (singersl.com) product links only.
    static func identify(url text: String) async throws -> IdentificationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            throw IdentificationError.notFound
        }
        let supported = Retailer.allCases.map(\.website)
        guard supported.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            throw IdentificationError.unsupportedRetailer
        }

        let matches: [URLMatchRow] = try await backend {
            try await supabase.rpc("find_product_by_url", params: URLParams(productUrl: trimmed)).execute().value
        }
        guard let match = matches.first, match.confidence >= 0.45,
              let product = ProductCatalog.product(id: match.productId) else {
            throw IdentificationError.notFound
        }
        return IdentificationResult(product: product, confidence: match.confidence, method: .url, evidence: host)
    }

    private static func backend<T>(_ call: () async throws -> T) async throws -> T {
        do {
            return try await call()
        } catch {
            throw IdentificationError.offline
        }
    }
}
