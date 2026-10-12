import SwiftUI

struct DemoDataBadge: View {
    var text: String = "Demo Data"

    var body: some View {
        Label(text, systemImage: "sparkles")
            .font(BuyWiseTypography.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(BuyWiseColors.surfaceSecondary))
            .foregroundStyle(BuyWiseColors.textSecondary)
    }
}
