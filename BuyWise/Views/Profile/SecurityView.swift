import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var twoFactorEnabled = false
    @State private var showChangePassword = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordResult: String?

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
            if appState.isGuest {
                Button("OK", role: .cancel) {}
            } else {
                SecureField("New password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
                Button("Update", action: updatePassword)
                Button("Cancel", role: .cancel) { clearPasswordFields() }
            }
        } message: {
            Text(appState.isGuest
                 ? "You're using a guest account. Create an account from the login screen to set a password."
                 : "Use at least 6 characters.")
        }
        .alert("Change password", isPresented: Binding(get: { passwordResult != nil }, set: { if !$0 { passwordResult = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(passwordResult ?? "")
        }
    }

    private func updatePassword() {
        let password = newPassword
        let matches = password == confirmPassword
        clearPasswordFields()
        guard password.count >= 6, matches else {
            passwordResult = matches ? "Use at least 6 characters." : "The passwords didn't match."
            return
        }
        Task {
            do {
                try await appState.changePassword(password)
                passwordResult = "Your password has been updated."
            } catch {
                passwordResult = error.userFacingMessage
            }
        }
    }

    private func clearPasswordFields() {
        newPassword = ""
        confirmPassword = ""
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
