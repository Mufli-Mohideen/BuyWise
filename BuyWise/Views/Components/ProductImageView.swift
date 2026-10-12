import SwiftUI

/// Displays a real bundled product photo when one is available, falling back to a
/// neutral tile with a product-accurate glyph (never an empty placeholder).
struct ProductImageView: View {
    let category: ProductCategory
    var symbolName: String? = nil
    var brand: String? = nil
    var assetName: String? = nil
    var cornerRadius: CGFloat = BuyWiseTheme.cardRadius
    var emphasized: Bool = false
    /// Only enable where the surrounding layout has no brand text of its own —
    /// most cards already show the brand as a caption, so the tag would duplicate it.
    var showsBrandTag: Bool = false

    init(product: Product, cornerRadius: CGFloat = BuyWiseTheme.cardRadius, emphasized: Bool = false, showsBrandTag: Bool = false) {
        self.category = product.category
        self.symbolName = product.imageSymbolName
        self.brand = product.brand
        self.assetName = product.imageAssetName
        self.cornerRadius = cornerRadius
        self.emphasized = emphasized
        self.showsBrandTag = showsBrandTag
    }

    init(category: ProductCategory, cornerRadius: CGFloat = BuyWiseTheme.cardRadius, emphasized: Bool = false) {
        self.category = category
        self.symbolName = nil
        self.brand = nil
        self.assetName = nil
        self.cornerRadius = cornerRadius
        self.emphasized = emphasized
        self.showsBrandTag = false
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tileFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(BuyWiseColors.border, lineWidth: 1)
            )
            .overlay {
                if let assetName, UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: symbolName ?? category.symbolName)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(emphasized ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if showsBrandTag, let brand {
                    Text(brand.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(BuyWiseColors.surface.opacity(0.92)))
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .padding(6)
                }
            }
            .accessibilityLabel(accessibilityLabelText)
    }

    private var tileFill: Color {
        guard let assetName else { return BuyWiseColors.surfaceSecondary }
        return UIImage(named: assetName) != nil ? Color(white: 0.98) : BuyWiseColors.surfaceSecondary
    }

    private var accessibilityLabelText: String {
        if let brand {
            return "\(brand) product photo"
        }
        return "\(category.rawValue) product image"
    }
}
