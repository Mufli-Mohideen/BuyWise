import SwiftUI

/// Confirms that every store's listing is the same product, so the prices above compare like for like.
struct ListingMatchCard: View {
    let product: Product
    let match: ListingMatch

    private var isMatch: Bool { match.comparison.isMatch }

    private var storeNames: String {
        ListFormatter.localizedString(byJoining: match.titles.map(\.retailer.rawValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: isMatch ? "Same product at every store" : "Check the model")

            FlowLayout(spacing: 10) {
                ForEach(match.titles, id: \.retailer) { item in
                    HStack(spacing: 6) {
                        RetailerLogoView(retailer: item.retailer, height: 14)
                        Image(systemName: isMatch ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(isMatch ? BuyWiseColors.success : BuyWiseColors.warning)
                    }
                }
            }

            Text(isMatch
                 ? "\(storeNames) \(match.titles.count == 2 ? "both" : "all") sell the \(product.fullName), so the prices above are for the same product."
                 : "The listings at \(storeNames) may not be the same model, so check before you buy.")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bwCard()
    }
}
