import SwiftUI

struct SignUpView: View {
    var onAccountCreated: () -> Void
    var onBackToLogin: () -> Void

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @Environment(\.dismiss) private var dismiss

    private var canCreateAccount: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && password == confirmPassword
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
                    }

                    Text("By creating an account, you agree to BuyWise's Terms of Service and Privacy Policy.")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .multilineTextAlignment(.center)

                    PrimaryButton(title: "Create Account", isEnabled: canCreateAccount, action: onAccountCreated)

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
