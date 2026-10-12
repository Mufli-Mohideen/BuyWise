import SwiftUI

/// A smaller product card used for alternatives, saved items and compact rails.
struct CompactProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProductImageView(product: product, cornerRadius: BuyWiseTheme.smallRadius, showsBrandTag: true)
                .frame(height: 92)

            Text(product.name)
                .font(BuyWiseTypography.subheadline)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 38, alignment: .top)

            Text(PriceFormatter.lkr(product.startingPrice))
                .font(BuyWiseTypography.priceSmall)
                .foregroundStyle(BuyWiseColors.textPrimary)

            ValueScoreBadge(score: product.valueScore.overall)

            Text(product.keySpec)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 32, alignment: .top)
        }
        .padding(10)
        .frame(width: 156, alignment: .leading)
        .bwCard(radius: BuyWiseTheme.smallRadius)
    }
}
