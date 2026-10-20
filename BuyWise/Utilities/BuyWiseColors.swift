import SwiftUI

/// Colors work with both the system appearance and a `.preferredColorScheme` override.
enum BuyWiseColors {
    // MARK: Brand

    static let brand = Color(hex: "FF6A00")
    static let brandDeep = Color(hex: "E85D04")
    static let brandSoft = Color.dynamic(light: "FFF1E8", dark: "2B1B10")

    // MARK: Surfaces

    static let background = Color.dynamic(light: "F7F7F7", dark: "101010")
    static let surface = Color.dynamic(light: "FFFFFF", dark: "1C1C1E")
    static let surfaceSecondary = Color.dynamic(light: "F7F7F7", dark: "252525")

    // MARK: Text

    static let textPrimary = Color.dynamic(light: "171717", dark: "FFFFFF")
    static let textSecondary = Color.dynamic(light: "707070", dark: "A1A1AA")
    static let textOnBrand = Color.white

    // MARK: Structure

    static let border = Color.dynamic(light: "E5E5E5", dark: "333333")

    // MARK: Semantic

    static let success = Color.dynamic(light: "16A34A", dark: "22C55E")
    static let warning = Color.dynamic(light: "F59E0B", dark: "FBBF24")
    static let error = Color.dynamic(light: "DC2626", dark: "F87171")
}
