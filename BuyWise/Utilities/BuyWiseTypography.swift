import SwiftUI

/// Centralized BuyWise type scale, built on semantic text styles so every size
/// scales correctly with the user's Dynamic Type setting. Prices use a rounded
/// design for a friendlier, more commercial feel than the rest of the UI.
enum BuyWiseTypography {
    static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let titleXL = Font.system(.title, design: .default).weight(.bold)
    static let title = Font.system(.title3, design: .default).weight(.bold)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let subheadline = Font.system(.subheadline, design: .default).weight(.medium)
    static let body = Font.system(.callout, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let captionBold = Font.system(.caption, design: .default).weight(.semibold)

    static let priceXL = Font.system(.title, design: .rounded).weight(.bold)
    static let priceLarge = Font.system(.title2, design: .rounded).weight(.bold)
    static let priceMedium = Font.system(.headline, design: .rounded).weight(.semibold)
    static let priceSmall = Font.system(.footnote, design: .rounded).weight(.semibold)
}
