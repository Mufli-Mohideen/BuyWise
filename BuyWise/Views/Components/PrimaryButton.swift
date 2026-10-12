import SwiftUI

struct PrimaryButton: View {
    let title: String
    var symbolName: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(BuyWiseTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                    .fill(isEnabled ? BuyWiseColors.brand : BuyWiseColors.brand.opacity(0.4))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbolName: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(BuyWiseTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(BuyWiseColors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                    .fill(BuyWiseColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                    .strokeBorder(BuyWiseColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A subtle press-down scale used across all BuyWise buttons and cards.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
