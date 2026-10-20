import SwiftUI

struct PriceDropBadge: View {
    let percent: Double
    var style: Style = .filled

    enum Style { case filled, subtle }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(PriceFormatter.percent(percent))
                .font(BuyWiseTypography.captionBold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(style == .filled ? BuyWiseColors.success : BuyWiseColors.success.opacity(0.15)))
        .foregroundStyle(style == .filled ? .white : BuyWiseColors.success)
    }
}

struct ValueScoreBadge: View {
    let score: Double
    var style: Style = .pill

    enum Style { case pill, plain }

    var body: some View {
        let color = BuyWiseTheme.valueScoreColor(score)
        switch style {
        case .pill:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                Text("\(String(format: "%.1f", score)) Value")
                    .font(BuyWiseTypography.captionBold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
        case .plain:
            Text("\(String(format: "%.1f", score)) / 10 Value")
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(color)
        }
    }
}

enum ProductBadgeKind: Hashable {
    case bestPrice, priceDrop, strongValue, sameProduct

    var title: String {
        switch self {
        case .bestPrice: return "Best Price"
        case .priceDrop: return "Price Drop"
        case .strongValue: return "Strong Value"
        case .sameProduct: return "Same Product"
        }
    }

    var symbolName: String {
        switch self {
        case .bestPrice: return "tag.fill"
        case .priceDrop: return "arrow.down.right.circle.fill"
        case .strongValue: return "checkmark.seal.fill"
        case .sameProduct: return "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bestPrice: return BuyWiseColors.brand
        case .priceDrop: return BuyWiseColors.success
        case .strongValue: return BuyWiseColors.success
        case .sameProduct: return BuyWiseColors.textSecondary
        }
    }
}

struct ProductBadge: View {
    let kind: ProductBadgeKind

    var body: some View {
        Label(kind.title, systemImage: kind.symbolName)
            .font(BuyWiseTypography.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(kind.tint.opacity(0.12)))
            .foregroundStyle(kind.tint)
    }
}
