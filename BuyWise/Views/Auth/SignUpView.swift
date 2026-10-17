import SwiftUI

struct SignUpView: View {
    var onAccountCreated: () -> Void
    var onBackToLogin: () -> Void

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isWorking = false
    @State private var message: String?
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private static let minimumPasswordLength = 6

    private var canCreateAccount: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && password.count >= Self.minimumPasswordLength
            && password == confirmPassword
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
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("Create account")
                            .font(BuyWiseTypography.titleXL)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("Join BuyWise to track prices and compare smarter.")
                            .font(BuyWiseTypography.body)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 14) {
                        labeledField(title: "Full name") {
                            TextField("Your name", text: $fullName)
                                .textInputAutocapitalization(.words)
                        }
                        labeledField(title: "Email") {
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        labeledField(title: "Password") {
                            HStack {
                                Group {
                                    if isPasswordVisible {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundStyle(BuyWiseColors.textSecondary)
                                }
                            }
                        }
                        labeledField(title: "Confirm password") {
                            SecureField("Confirm password", text: $confirmPassword)
                        }
                        if let hint = passwordHint ?? message {
                            Text(hint)
                                .font(BuyWiseTypography.caption)
                                .foregroundStyle(passwordHint != nil ? BuyWiseColors.error : BuyWiseColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Text("By creating an account, you agree to BuyWise's Terms of Service and Privacy Policy.")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .multilineTextAlignment(.center)

                    PrimaryButton(title: "Create Account", isLoading: isWorking, isEnabled: canCreateAccount && !isWorking, action: createAccount)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(BuyWiseTypography.body)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                        Button("Sign in") {
                            dismiss()
                            onBackToLogin()
                        }
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.brand)
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
            }
            .bwScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
        }
    }

    private func createAccount() {
        isWorking = true
        message = nil
        Task {
            do {
                if try await appState.signUp(name: fullName, email: email, password: password) {
                    onAccountCreated()
                } else {
                    message = "Check \(email) for a confirmation link, then sign in."
                }
            } catch {
                message = error.userFacingMessage
            }
            isWorking = false
        }
    }

    private func labeledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
            content()
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
}
