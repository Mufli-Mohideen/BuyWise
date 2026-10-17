import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var twoFactorEnabled = false
    @State private var showChangePassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    NavigationLink {
                        FaceIDSettingsView()
                    } label: {
                        settingsRow(title: "Face ID", symbol: "faceid", detail: appState.isFaceIDEnabled ? "Enabled" : "Disabled")
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(BuyWiseColors.border).padding(.leading, 58)

                    Button {
                        showChangePassword = true
                    } label: {
                        settingsRow(title: "Change Password", symbol: "key")
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(BuyWiseColors.border).padding(.leading, 58)

                    HStack(spacing: 12) {
                        iconTile("lock.rotation")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Two-Factor Authentication")
                                .font(BuyWiseTypography.body)
                                .foregroundStyle(BuyWiseColors.textPrimary)
                            Text("Adds an extra layer of security at sign in.")
                                .font(BuyWiseTypography.caption)
                                .foregroundStyle(BuyWiseColors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $twoFactorEnabled)
                            .labelsHidden()
                            .tint(BuyWiseColors.brand)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                }
                .bwCard()
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Change password", isPresented: $showChangePassword) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This is a demo prototype — password changes aren't available.")
        }
    }

    private func iconTile(_ symbol: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(BuyWiseColors.brandSoft)
                .frame(width: 32, height: 32)
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(BuyWiseColors.brand)
        }
    }

    private func settingsRow(title: String, symbol: String, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            iconTile(symbol)
            Text(title)
                .font(BuyWiseTypography.body)
                .foregroundStyle(BuyWiseColors.textPrimary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BuyWiseColors.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }
}
