import SwiftUI

struct RetailerPriceCard: View {
    let listing: RetailerListing
    let isLowest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RetailerLogoView(retailer: listing.retailer, height: 18)

            if isLowest {
                ProductBadge(kind: .bestPrice)
                    .fixedSize()
            }

            Text(PriceFormatter.lkr(listing.price))
                .font(BuyWiseTypography.priceLarge)
                .foregroundStyle(isLowest ? BuyWiseColors.textPrimary : BuyWiseColors.textSecondary)

            Label(listing.isAvailable ? "Available" : "Unavailable", systemImage: listing.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(listing.isAvailable ? BuyWiseColors.success : BuyWiseColors.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BuyWiseTheme.smallRadius, style: .continuous)
                .fill(isLowest ? BuyWiseColors.brandSoft : BuyWiseColors.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuyWiseTheme.smallRadius, style: .continuous)
                .strokeBorder(isLowest ? BuyWiseColors.brand.opacity(0.35) : .clear, lineWidth: 1.2)
        )
    }
}
