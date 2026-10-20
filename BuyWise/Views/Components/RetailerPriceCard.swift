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

    private var availabilityStatus: (text: String, symbol: String, color: Color) {
        if listing.isAvailable { return ("Available", "checkmark.circle.fill", BuyWiseColors.success) }
        if listing.isPreorder { return ("Pre-order", "clock", BuyWiseColors.brand) }
        return ("Unavailable", "xmark.circle", BuyWiseColors.textSecondary)
    }

    private var availability: some View {
        let status = availabilityStatus
        return Label(status.text, systemImage: status.symbol)
            .font(BuyWiseTypography.caption)
            .foregroundStyle(status.color)
    }
}
