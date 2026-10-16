import SwiftUI

struct TrackedView: View {
    @EnvironmentObject private var appState: AppState
    @State private var simulating: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracked")
                        .font(BuyWiseTypography.titleXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("We'll alert you when these prices drop.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }

                if appState.trackedProducts.isEmpty {
                    EmptyStateView(
                        symbolName: "bell.slash",
                        title: "No tracked products yet",
                        subtitle: "Track a product from its details screen to see it here."
                    )
                } else {
                    summary
                    demoCard
                    LazyVStack(spacing: 12) {
                        ForEach(appState.trackedProducts) { product in
                            TrackedProductCard(
                                product: product,
                                previousPrice: appState.previousPrice(for: product) ?? product.startingPrice,
                                onRemove: { withAnimation { appState.stopTracking(product) } }
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Tracked")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile(value: PriceFormatter.lkr(appState.totalTrackedSavings), label: "Saved since tracking", symbol: "arrow.down.right.circle.fill", tint: BuyWiseColors.success)
            summaryTile(value: "\(appState.trackedProducts.filter { appState.priceAlertsEnabled(for: $0) }.count) of \(appState.trackedProducts.count)", label: "Alerts on", symbol: "bell.badge.fill", tint: BuyWiseColors.brand)
        }
    }

    private func summaryTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(tint)
            Text(value)
                .font(BuyWiseTypography.priceMedium)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .bwCard()
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(BuyWiseColors.brand))
                VStack(alignment: .leading, spacing: 2) {
                    Text("See a price-drop alert")
                        .font(BuyWiseTypography.headline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Demo: lower a tracked price the way a store update would.")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.trackedProducts) { product in
                        Button {
                            simulating = product.id
                            Task {
                                await appState.simulatePriceDrop(for: product)
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                simulating = nil
                            }
                        } label: {
                            HStack(spacing: 8) {
                                ProductImageView(product: product, cornerRadius: 6).frame(width: 26, height: 26)
                                Text(product.name)
                                    .font(BuyWiseTypography.captionBold)
                                    .foregroundStyle(BuyWiseColors.textPrimary)
                                if simulating == product.id {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.down.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(BuyWiseColors.success)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(BuyWiseColors.surface))
                            .overlay(Capsule().strokeBorder(BuyWiseColors.border, lineWidth: 1))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(simulating != nil)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous).fill(BuyWiseColors.brandSoft))
        .overlay(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous).strokeBorder(BuyWiseColors.brand.opacity(0.25), lineWidth: 1))
    }
}
