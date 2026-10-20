import SwiftUI

struct InsightCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BuyWiseColors.brandSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: "lightbulb.max.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(BuyWiseColors.brand)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("BuyWise Insight")
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(BuyWiseColors.brand)
                Text(message)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .fill(BuyWiseColors.brandSoft)
        )
    }
}
