import SwiftUI

struct CategoryPicker: View {
    @Binding var selection: ProductCategory

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ProductCategory.allCases) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = category }
                } label: {
                    Text(category.rawValue)
                        .font(BuyWiseTypography.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(selection == category ? BuyWiseColors.brand : BuyWiseColors.surfaceSecondary))
                        .foregroundStyle(selection == category ? .white : BuyWiseColors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
