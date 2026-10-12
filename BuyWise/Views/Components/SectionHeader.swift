import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BuyWiseTypography.title)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.brand)
                }
            }
        }
    }
}
