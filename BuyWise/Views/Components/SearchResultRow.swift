import SwiftUI

struct SearchResultRow: View {
    let product: Product

    private var badges: [ProductBadgeKind] {
        var result: [ProductBadgeKind] = []
        if product.valueScore.overall >= 8.5 { result.append(.strongValue) }
        if product.savings > 3000 { result.append(.bestPrice) }
        return result
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProductImageView(product: product, cornerRadius: BuyWiseTheme.smallRadius)
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(product.brand)
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                        Text(product.name)
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(product.category.rawValue)
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }

                // Wraps when three stores' seven-digit prices don't fit on one line.
                FlowLayout(spacing: 14) {
                    ForEach(Retailer.allCases) { retailer in
                        if let listing = product.listing(for: retailer) {
                            retailerPrice(retailer.rawValue, listing: listing)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Text("Lowest \(PriceFormatter.lkr(product.startingPrice))")
                        .font(BuyWiseTypography.priceSmall)
                        .foregroundStyle(BuyWiseColors.brand)
                    ValueScoreBadge(score: product.valueScore.overall)
                }

                if !badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badges, id: \.self) { badge in
                            ProductBadge(kind: badge)
                        }
                    }
                }
            }
        }
        .padding(12)
        .bwCard(radius: BuyWiseTheme.controlRadius)
    }

    private func retailerPrice(_ name: String, listing: RetailerListing) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
            Text(PriceFormatter.lkr(listing.price))
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textPrimary)
        }
    }
}
