import SwiftUI

struct ShoppingPrioritiesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let preview = [ProductCatalog.sonyWH1000XM5, ProductCatalog.macBookAirM3, ProductCatalog.xiaomi14TPro]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tell BuyWise what matters most. Value scores re-weight the specifications to match.")
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(ShoppingPriority.allCases.enumerated()), id: \.element) { index, priority in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appState.shoppingPriority = priority }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: priority.symbolName)
                                    .font(.system(size: 15))
                                    .foregroundStyle(BuyWiseColors.brand)
                                    .frame(width: 34, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(BuyWiseColors.brandSoft))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(priority.rawValue)
                                        .font(BuyWiseTypography.body)
                                        .foregroundStyle(BuyWiseColors.textPrimary)
                                    Text(priority.detail)
                                        .font(BuyWiseTypography.caption)
                                        .foregroundStyle(BuyWiseColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: appState.shoppingPriority == priority ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(appState.shoppingPriority == priority ? BuyWiseColors.brand : BuyWiseColors.border)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < ShoppingPriority.allCases.count - 1 {
                            Divider().overlay(BuyWiseColors.border).padding(.leading, 60)
                        }
                    }
                }
                .bwCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("LIVE PREVIEW")
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    VStack(spacing: 0) {
                        ForEach(preview) { product in
                            HStack(spacing: 12) {
                                ProductImageView(product: product, cornerRadius: 8).frame(width: 40, height: 40)
                                Text(product.name)
                                    .font(BuyWiseTypography.subheadline)
                                    .foregroundStyle(BuyWiseColors.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f", product.valueScore.overall))
                                    .font(BuyWiseTypography.priceMedium)
                                    .foregroundStyle(BuyWiseTheme.valueScoreColor(product.valueScore.overall))
                                    .contentTransition(.numericText())
                            }
                            .padding(12)
                        }
                    }
                    .bwCard()
                }
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Shopping priorities")
        .navigationBarTitleDisplayMode(.inline)
    }
}
