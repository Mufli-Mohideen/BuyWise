import SwiftUI

enum BuyWiseTheme {
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 14
    static let smallRadius: CGFloat = 10

    static func valueScoreColor(_ score: Double) -> Color {
        switch score {
        case 7.5...: return BuyWiseColors.success
        case 6..<7.5: return BuyWiseColors.warning
        default: return BuyWiseColors.error
        }
    }

    static func valueScoreLabel(_ score: Double) -> String {
        switch score {
        case 7.5...: return "Strong Value"
        case 6..<7.5: return "Fair Value"
        default: return "Below Average Value"
        }
    }
}

private struct BWCardModifier: ViewModifier {
    var radius: CGFloat = BuyWiseTheme.cardRadius
    var fill: Color = BuyWiseColors.surface
    var bordered: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(bordered ? BuyWiseColors.border : .clear, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

extension View {
    /// The standard BuyWise white/dark card surface with a thin border and soft shadow.
    func bwCard(radius: CGFloat = BuyWiseTheme.cardRadius) -> some View {
        modifier(BWCardModifier(radius: radius))
    }

    /// A recessed secondary surface (no border, flat) used for nested rows inside a card.
    func bwSecondarySurface(radius: CGFloat = BuyWiseTheme.smallRadius) -> some View {
        modifier(BWCardModifier(radius: radius, fill: BuyWiseColors.surfaceSecondary, bordered: false))
    }

    func bwScreenBackground() -> some View {
        background(BuyWiseColors.background.ignoresSafeArea())
    }
}
