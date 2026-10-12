import SwiftUI

struct IdentifyOptionRow: View {
    let title: String
    let subtitle: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BuyWiseColors.brandSoft)
                    .frame(width: 46, height: 46)
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(BuyWiseColors.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(subtitle)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BuyWiseColors.textSecondary.opacity(0.6))
        }
        .padding(14)
        .bwCard(radius: BuyWiseTheme.controlRadius)
    }
}
