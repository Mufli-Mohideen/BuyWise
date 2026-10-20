import SwiftUI

/// Logos sit on a white chip because they carry their own brand colors.
struct RetailerLogoView: View {
    let retailer: Retailer
    var height: CGFloat = 20

    var body: some View {
        Image(retailer.logoAssetName)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
            )
    }
}

/// The retailer's logo in a white circle, shown beside store names.
struct RetailerLogoCircle: View {
    let retailer: Retailer
    let size: CGFloat
    let padding: CGFloat

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(Image(retailer.logoAssetName).resizable().scaledToFit().padding(padding))
            .overlay(Circle().strokeBorder(BuyWiseColors.border, lineWidth: 1))
    }
}
