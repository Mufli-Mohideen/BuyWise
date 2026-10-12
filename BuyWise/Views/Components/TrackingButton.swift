import SwiftUI

struct TrackingButton: View {
    let isTracking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isTracking ? "checkmark.circle.fill" : "bell.badge")
                    .font(.system(size: 16, weight: .semibold))
                Text(isTracking ? "Tracking" : "Track price")
                    .font(BuyWiseTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(isTracking ? BuyWiseColors.success : .white)
            .background(
                RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                    .fill(isTracking ? BuyWiseColors.success.opacity(0.14) : BuyWiseColors.brand)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isTracking)
    }
}
