import SwiftUI

enum ComparisonWinner { case none, first, second }

struct ComparisonRow: View {
    let title: String
    let valueA: String
    let valueB: String
    var winner: ComparisonWinner = .none

    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                valueLabel(valueA, isWinner: winner == .first)
                    .frame(maxWidth: .infinity, alignment: .leading)
                valueLabel(valueB, isWinner: winner == .second)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .bwSecondarySurface()
    }

    private func valueLabel(_ text: String, isWinner: Bool) -> some View {
        HStack(spacing: 4) {
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(BuyWiseColors.success)
            }
            Text(text)
                .font(BuyWiseTypography.subheadline)
                .foregroundStyle(isWinner ? BuyWiseColors.textPrimary : BuyWiseColors.textSecondary)
                .fontWeight(isWinner ? .semibold : .regular)
        }
    }
}
