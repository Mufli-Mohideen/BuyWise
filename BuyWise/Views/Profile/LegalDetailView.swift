import SwiftUI

struct LegalDetailView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(BuyWiseTypography.body)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
