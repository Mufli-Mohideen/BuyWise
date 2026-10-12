import SwiftUI

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BuyWiseColors.brandSoft)
                    .frame(width: 64, height: 64)
                Image(systemName: symbolName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(BuyWiseColors.brand)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(BuyWiseTypography.headline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(subtitle)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.brand)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
