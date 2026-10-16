import SwiftUI
import Charts

struct TrackedProductCard: View {
    let product: Product
    let previousPrice: Double
    @EnvironmentObject private var appState: AppState
    var onRemove: () -> Void

    private var currentPrice: Double { product.startingPrice }
    private var priceChange: Double { currentPrice - previousPrice }
    private var percentChange: Double {
        guard previousPrice > 0 else { return 0 }
        return abs(priceChange) / previousPrice * 100
    }
    private var isDrop: Bool { priceChange < 0 }
    private var recentHistory: [PricePoint] { Array(product.priceHistory.suffix(6)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ProductImageView(product: product, cornerRadius: BuyWiseTheme.smallRadius, emphasized: true)
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.textPrimary)

                    Text(PriceFormatter.lkr(currentPrice))
                        .font(BuyWiseTypography.priceLarge)
                        .foregroundStyle(BuyWiseColors.textPrimary)

                    if priceChange != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: isDrop ? "arrow.down" : "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                            Text(PriceFormatter.lkr(abs(priceChange)))
                        }
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(isDrop ? BuyWiseColors.success : BuyWiseColors.error)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Chart(recentHistory) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Price", point.price)
                        )
                        .foregroundStyle(isDrop ? BuyWiseColors.success : BuyWiseColors.brand)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: 64, height: 32)

                    if priceChange != 0 {
                        PriceDropBadge(percent: percentChange, style: isDrop ? .filled : .subtle)
                    }
                }
            }

            Divider().overlay(BuyWiseColors.border)

            HStack {
                Toggle(isOn: Binding(
                    get: { appState.priceAlertsEnabled(for: product) },
                    set: { appState.setPriceAlerts($0, for: product) }
                )) {
                    Text("Price alerts")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                .tint(BuyWiseColors.brand)
                .fixedSize()

                Spacer()

                NavigationLink(value: product) {
                    Text("View Product")
                }
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.brand)

                Button("Remove", role: .destructive, action: onRemove)
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(BuyWiseColors.error)
            }
        }
        .padding(14)
        .bwCard()
    }
}
