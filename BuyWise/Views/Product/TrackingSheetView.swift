import SwiftUI

struct TrackingSheetView: View {
    let product: Product
    var onStartTracking: (_ threshold: Double, _ alertsEnabled: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var threshold: Double = 5
    @State private var alertsEnabled = true

    private let thresholdOptions: [Double] = [3, 5, 10, 15]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Track this product?")
                        .font(BuyWiseTypography.titleXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Get notified when the price changes.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }

                HStack(spacing: 14) {
                    ProductImageView(product: product, cornerRadius: BuyWiseTheme.smallRadius, emphasized: true)
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        HStack(spacing: 4) {
                            Text("Current price")
                                .font(BuyWiseTypography.caption)
                                .foregroundStyle(BuyWiseColors.textSecondary)
                            Text(PriceFormatter.lkr(product.startingPrice))
                                .font(BuyWiseTypography.priceSmall)
                                .foregroundStyle(BuyWiseColors.textPrimary)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .bwSecondarySurface()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notify me when price drops by")
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    HStack(spacing: 8) {
                        ForEach(thresholdOptions, id: \.self) { option in
                            Button {
                                threshold = option
                            } label: {
                                Text("\(Int(option))%")
                                    .font(BuyWiseTypography.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule().fill(threshold == option ? BuyWiseColors.brand : BuyWiseColors.surfaceSecondary)
                                    )
                                    .foregroundStyle(threshold == option ? .white : BuyWiseColors.textPrimary)
                            }
                        }
                    }
                }

                Toggle(isOn: $alertsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Push notifications")
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("Get notified when the price of this product drops.")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                }
                .tint(BuyWiseColors.brand)

                Spacer()

                PrimaryButton(title: "Start tracking") {
                    onStartTracking(threshold, alertsEnabled)
                    dismiss()
                }
            }
            .padding(20)
            .bwScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
