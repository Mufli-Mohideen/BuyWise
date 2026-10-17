import SwiftUI
import LocalAuthentication

/// Shown on launch when a saved session exists and the user turned on Face ID.
struct FaceIDLockView: View {
    var onUnlocked: () -> Void
    var onUsePassword: () -> Void

    @State private var isAuthenticating = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(BuyWiseColors.surface)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                Image("BuyWiseLogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            }

            VStack(spacing: 6) {
                Text("BuyWise is locked")
                    .font(BuyWiseTypography.titleXL)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(statusMessage ?? "Unlock with Face ID to continue.")
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Unlock", symbolName: "faceid", isLoading: isAuthenticating, action: unlock)
                Button("Use password instead", action: onUsePassword)
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.brand)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .bwScreenBackground()
        .task { unlock() }
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        statusMessage = nil
        let context = LAContext()
        var error: NSError?

        // No Face ID or passcode set up (e.g. Simulator): there's nothing to verify against.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isAuthenticating = false
            onUnlocked()
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your BuyWise account.") { success, _ in
            Task { @MainActor in
                isAuthenticating = false
                if success {
                    onUnlocked()
                } else {
                    statusMessage = "Face ID didn't match. Try again or sign in with your password."
                }
            }
        }
    }
}
