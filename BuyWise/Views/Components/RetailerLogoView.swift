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
