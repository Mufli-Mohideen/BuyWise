import SwiftUI

/// Shows the category glyph while loading or when there's no photo.
struct ProductPhoto: View {
    let product: Product?
    var category: ProductCategory = .smartphones
    var padding: CGFloat = 8
    var placeholderTint: Color = BuyWiseColors.textSecondary

    var body: some View {
        if let assetName = product?.imageAssetName, UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .padding(padding)
        } else if let url = product?.imageURL {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().padding(padding)
                } else {
                    glyph
                }
            }
        } else {
            glyph
        }
    }

    private var glyph: some View {
        Image(systemName: product?.imageSymbolName ?? category.symbolName)
            .font(.system(size: 34, weight: .medium))
            .foregroundStyle(placeholderTint)
    }
}

struct ProductImageView: View {
    let category: ProductCategory
    var product: Product? = nil
    var brand: String? = nil
    var cornerRadius: CGFloat = BuyWiseTheme.cardRadius
    var emphasized: Bool = false
    /// Most cards already show the brand, so only enable this where they don't.
    var showsBrandTag: Bool = false

    init(product: Product, cornerRadius: CGFloat = BuyWiseTheme.cardRadius, emphasized: Bool = false, showsBrandTag: Bool = false) {
        self.category = product.category
        self.product = product
        self.brand = product.brand
        self.cornerRadius = cornerRadius
        self.emphasized = emphasized
        self.showsBrandTag = showsBrandTag
    }

    init(category: ProductCategory, cornerRadius: CGFloat = BuyWiseTheme.cardRadius, emphasized: Bool = false) {
        self.category = category
        self.cornerRadius = cornerRadius
        self.emphasized = emphasized
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(hasPhoto ? Color(white: 0.98) : BuyWiseColors.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(BuyWiseColors.border, lineWidth: 1)
            )
            .overlay {
                ProductPhoto(product: product, category: category,
                             placeholderTint: emphasized ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
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

    private var hasPhoto: Bool {
        if let assetName = product?.imageAssetName, UIImage(named: assetName) != nil { return true }
        return product?.imageURL != nil
    }

    private var accessibilityLabelText: String {
        if let brand {
            return "\(brand) product photo"
        }
        return "\(category.rawValue) product image"
    }
}
