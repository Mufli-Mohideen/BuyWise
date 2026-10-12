import SwiftUI

struct SearchBar: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    var isButton: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        if isButton {
            Button(action: { onTap?() }) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(BuyWiseColors.textSecondary)

            if isButton {
                Text(placeholder)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Spacer()
            } else {
                TextField(placeholder, text: $text)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { onSubmit?() }

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .fill(BuyWiseColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .strokeBorder(BuyWiseColors.border, lineWidth: 1)
        )
    }
}
