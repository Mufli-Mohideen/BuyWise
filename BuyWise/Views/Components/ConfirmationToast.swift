import SwiftUI

struct ConfirmationToast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(BuyWiseTypography.captionBold)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(BuyWiseColors.textPrimary))
            .foregroundStyle(BuyWiseColors.background)
            .padding(.top, 8)
    }
}
