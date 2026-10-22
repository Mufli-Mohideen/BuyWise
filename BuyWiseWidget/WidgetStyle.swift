import SwiftUI
import WidgetKit

enum WidgetStyle {
    static let brand = Color(red: 1, green: 0x6A / 255, blue: 0)
    static let brandGradient = LinearGradient(
        colors: [Color(red: 1, green: 0x7A / 255, blue: 0x1A / 255), brand, Color(red: 0xD9 / 255, green: 0x4E / 255, blue: 0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let success = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)

    static func lkr(_ value: Double) -> String {
        "LKR " + value.formatted(.number.grouping(.automatic).precision(.fractionLength(0)).locale(Locale(identifier: "en_US")))
    }

    static func percent(_ value: Double) -> String {
        abs(value).formatted(.percent.precision(.fractionLength(0)))
    }
}

/// Product photo on a white tile, or a placeholder when there's no photo.
struct ProductThumbnail: View {
    let image: UIImage?
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(.white)
            .frame(width: size, height: size)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.1)
                } else {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(WidgetStyle.brand.opacity(0.6))
                }
            }
    }
}

struct DiscountBadge: View {
    let discount: Double

    var body: some View {
        Text("-\(WidgetStyle.percent(discount))")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(WidgetStyle.success))
    }
}

/// Shown when the catalogue can't be reached.
struct WidgetMessage: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(WidgetStyle.brand)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
