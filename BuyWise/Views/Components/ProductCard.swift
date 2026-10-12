import SwiftUI

struct ProductCard: View {
    let product: Product
    var onToggleSave: (() -> Void)? = nil
    var isSaved: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ProductImageView(product: product, emphasized: true)
                    .frame(height: 116)

                if let onToggleSave {
                    Button(action: onToggleSave) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSaved ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
                            .padding(7)
                            .background(Circle().fill(BuyWiseColors.surface.opacity(0.9)))
                    }
                    .padding(8)
                    .accessibilityLabel(isSaved ? "Remove from saved" : "Save product")
                }
            }

            Text(product.brand.uppercased())
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)

            Text(product.name)
                .font(BuyWiseTypography.subheadline)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 38, alignment: .top)

            VStack(alignment: .leading, spacing: 2) {
                Text("From")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Text(PriceFormatter.lkr(product.startingPrice))
                    .font(BuyWiseTypography.priceMedium)
                    .foregroundStyle(BuyWiseColors.textPrimary)
            }

            HStack {
                Text(product.lowestListing.retailer.rawValue)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Spacer()
                ValueScoreBadge(score: product.valueScore.overall)
            }
        }
        .padding(12)
        .frame(width: 172, alignment: .leading)
        .bwCard()
    }
}
