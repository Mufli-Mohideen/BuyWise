import SwiftUI
import AuthenticationServices

struct LoginView: View {
    var onSignedIn: () -> Void
    var onCreateAccount: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @AppStorage("rememberMe") private var rememberMe = true
    @State private var resetMessage: String?
    @State private var showGoogleUnavailable = false
    @State private var appleErrorMessage: String?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var appleNonce = ""
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BuyWiseColors.surface)
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                        Image("BuyWiseLogoMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }

                    VStack(spacing: 4) {
                        Text("Welcome back")
                            .font(BuyWiseTypography.titleXL)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("Make your next purchase a smarter one.")
                            .font(BuyWiseTypography.body)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                }
                .padding(.top, 24)

                VStack(spacing: 14) {
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

                    HStack {
                        Button {
                            rememberMe.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18))
                                    .foregroundStyle(rememberMe ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
                                Text("Remember me")
                                    .font(BuyWiseTypography.caption)
                                    .foregroundStyle(BuyWiseColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Forgot password?") { sendPasswordReset() }
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.brand)
                    }
                }

                VStack(spacing: 14) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: "Sign In", isLoading: isWorking, isEnabled: canSignIn && !isWorking) {
                        run { try await appState.signIn(email: email, password: password) }
                    }

                    HStack {
                        Rectangle().fill(BuyWiseColors.border).frame(height: 1)
                        Text("or continue with")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                            .fixedSize()
                        Rectangle().fill(BuyWiseColors.border).frame(height: 1)
                    }

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            appleNonce = AppleSignInNonce.random()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AppleSignInNonce.sha256(appleNonce)
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous))

                        googleButton
                    }
                }

                VStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(BuyWiseTypography.body)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                        Button("Create account", action: onCreateAccount)
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.brand)
                    }

                    Button {
                        run { try await appState.continueAsGuest() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text("Continue as Demo User")
                                .font(BuyWiseTypography.caption)
                        }
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                    .disabled(isWorking)
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
        .bwScreenBackground()
        .alert("Reset password", isPresented: Binding(get: { resetMessage != nil }, set: { if !$0 { resetMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetMessage ?? "")
        }
        .alert("Google sign-in", isPresented: $showGoogleUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Google sign-in isn't part of this prototype. Use Sign in with Apple or your email instead.")
        }
        .alert("Sign in with Apple", isPresented: Binding(get: { appleErrorMessage != nil }, set: { if !$0 { appleErrorMessage = nil } })) {
            Button("Continue as Demo User") {
                run { try await appState.continueAsGuest() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(appleErrorMessage ?? "")
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

    private var googleButton: some View {
        Button {
            showGoogleUnavailable = true
        } label: {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(BuyWiseColors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                    .fill(BuyWiseColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                    .strokeBorder(BuyWiseColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                appleErrorMessage = "Apple didn't return a sign-in token. Please try again."
                return
            }
            let fullName = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            let nonce = appleNonce
            run { try await appState.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            appleErrorMessage = "Sign in with Apple isn't enabled for this build. It needs a paid Apple Developer account."
        }
    }

    private func run(_ signIn: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await signIn()
                onSignedIn()
            } catch {
                errorMessage = error.userFacingMessage
            }
            isWorking = false
        }
    }

    private func sendPasswordReset() {
        let address = email.trimmingCharacters(in: .whitespaces)
        guard address.contains("@") else {
            resetMessage = "Enter your account email above, then tap Forgot password again."
            return
        }
        Task {
            do {
                try await appState.sendPasswordReset(email: address)
                resetMessage = "If an account exists for \(address), we've emailed a link to reset your password."
            } catch {
                resetMessage = error.userFacingMessage
            }
        }
    }
}
