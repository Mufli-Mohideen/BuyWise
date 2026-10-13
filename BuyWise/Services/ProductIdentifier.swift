import Foundation

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

    var errorDescription: String? {
        switch self {
        case .unsupportedRetailer: return "Only Singer and Abans product links are supported."
        case .notFound: return "We couldn't match this to a product in the catalogue."
        case .noTextFound: return "No readable text was found in this image."
        case .noBarcodeFound: return "No barcode was found in this image."
        }
    }
}

/// Maps free text (OCR output, URL slugs, typed names) and barcodes to catalogue products,
/// using the same on-device listing matcher that compares Singer and Abans listings.
enum ProductIdentifier {
    static func identify(text: String, method: IdentificationResult.Method) throws -> IdentificationResult {
        let query = text.replacingOccurrences(of: "\n", with: " ")
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { throw IdentificationError.noTextFound }

        var best: (Product, Double)?
        for product in ProductCatalog.all {
            let candidates = [
                product.fullName,
                CatalogMetadata.title(for: product, retailer: .singer),
                CatalogMetadata.title(for: product, retailer: .abans)
            ]
            let score = candidates
                .map { ListingMatcher.shared.compare(query, $0) }
                .filter { $0.conflictReason == nil && $0.modelMatched }
                .map(\.confidence)
                .max() ?? 0
            if score > (best?.1 ?? 0) {
                best = (product, score)
            }
        }

        guard let (product, confidence) = best, confidence >= 0.55 else { throw IdentificationError.notFound }
        return IdentificationResult(product: product, confidence: confidence, method: method, evidence: text)
    }

    static func identify(barcode: String) throws -> IdentificationResult {
        guard let product = CatalogMetadata.product(forBarcode: barcode) else { throw IdentificationError.notFound }
        return IdentificationResult(product: product, confidence: 1, method: .barcode, evidence: barcode)
    }

    /// Parses Singer (singersl.com / singer.lk) and Abans (buyabans.com) product links only.
    static func identify(url text: String) throws -> IdentificationResult {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased() else {
            throw IdentificationError.notFound
        }
        let supported = ["singersl.com", "singer.lk", "buyabans.com"]
        guard supported.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            throw IdentificationError.unsupportedRetailer
        }
        let slug = url.pathComponents.last { $0 != "/" } ?? ""
        let words = slug
            .replacingOccurrences(of: #"\.html?$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[-_]+"#, with: " ", options: .regularExpression)
        let result = try identify(text: words, method: .url)
        return IdentificationResult(product: result.product, confidence: result.confidence, method: .url, evidence: host)
    }
}
