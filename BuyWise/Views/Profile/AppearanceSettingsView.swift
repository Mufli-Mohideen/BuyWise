import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose how BuyWise looks on your device.")
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element) { index, mode in
                        Button {
                            withAnimation { appState.appearanceMode = mode }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(BuyWiseColors.brandSoft)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: mode.symbolName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(BuyWiseColors.brand)
                                }
                                Text(mode.rawValue)
                                    .font(BuyWiseTypography.body)
                                    .foregroundStyle(BuyWiseColors.textPrimary)
                                Spacer()
                                if appState.appearanceMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BuyWiseColors.brand)
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)

                        if index < AppearanceMode.allCases.count - 1 {
                            Divider().overlay(BuyWiseColors.border).padding(.leading, 58)
                        }
                    }
                }
                .bwCard()
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
