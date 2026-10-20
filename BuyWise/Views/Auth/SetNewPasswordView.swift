import SwiftUI

/// Shown after opening a password reset link from email.
struct SetNewPasswordView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var message: String?

    private static let minimumPasswordLength = 6

    private var canSave: Bool {
        password.count >= Self.minimumPasswordLength && password == confirmPassword
    }

    private var passwordHint: String? {
        if !password.isEmpty && password.count < Self.minimumPasswordLength {
            return "Use at least \(Self.minimumPasswordLength) characters."
        }
        if !confirmPassword.isEmpty && password != confirmPassword {
            return "Passwords don't match."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("Set a new password")
                        .font(BuyWiseTypography.titleXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Choose a new password for \(appState.userEmail).")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                VStack(spacing: 14) {
                    passwordField("New password", text: $password)
                    passwordField("Confirm new password", text: $confirmPassword)

                    if let hint = passwordHint ?? message {
                        Text(hint)
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                PrimaryButton(title: "Save password", isLoading: isWorking, isEnabled: canSave && !isWorking, action: save)

                Spacer()
            }
            .padding(24)
            .bwScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { appState.needsNewPassword = false }
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private func save() {
        isWorking = true
        message = nil
        Task {
            do {
                try await appState.changePassword(password)
                appState.needsNewPassword = false
            } catch {
                message = error.userFacingMessage
            }
            isWorking = false
        }
    }

    private func passwordField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textContentType(.newPassword)
            .font(BuyWiseTypography.body)
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
