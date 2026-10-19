import SwiftUI

struct RetailerPriceCard: View {
    let listing: RetailerListing
    let isLowest: Bool
    /// A single full-width row, used when three retailers' cards won't fit side by side.
    var isCompact = false

    var body: some View {
        Group {
            if isCompact {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        RetailerLogoView(retailer: listing.retailer, height: 16)
                        availability
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 6) {
                        if isLowest {
                            ProductBadge(kind: .bestPrice)
                                .fixedSize()
                        }
                        price
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    RetailerLogoView(retailer: listing.retailer, height: 18)

                    if isLowest {
                        ProductBadge(kind: .bestPrice)
                            .fixedSize()
                    }

                    price
                    availability
                }
            }
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

    private var price: some View {
        Text(PriceFormatter.lkr(listing.price))
            .font(BuyWiseTypography.priceLarge)
            .foregroundStyle(isLowest ? BuyWiseColors.textPrimary : BuyWiseColors.textSecondary)
            .lineLimit(1)
            .fixedSize()
    }

    private var availability: some View {
        Label(listing.isAvailable ? "Available" : listing.isPreorder ? "Pre-order" : "Unavailable",
              systemImage: listing.isAvailable ? "checkmark.circle.fill" : listing.isPreorder ? "clock" : "xmark.circle")
            .font(BuyWiseTypography.caption)
            .foregroundStyle(listing.isAvailable ? BuyWiseColors.success : listing.isPreorder ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
    }
}
