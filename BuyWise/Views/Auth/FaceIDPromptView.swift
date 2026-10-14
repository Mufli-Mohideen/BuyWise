import SwiftUI
import LocalAuthentication

struct FaceIDPromptView: View {
    var onFinished: (_ enabled: Bool) -> Void

    @State private var isAuthenticating = false
    @State private var statusMessage: String?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(BuyWiseColors.brandSoft)
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.08 : 1)
                Image(systemName: "faceid")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(BuyWiseColors.brand)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(spacing: 8) {
                Text("Secure BuyWise with Face ID")
                    .font(BuyWiseTypography.titleXL)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Use Face ID to securely access your BuyWise account.")
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Enable Face ID", symbolName: "faceid", isLoading: isAuthenticating, action: authenticate)
                Button("Not Now") { onFinished(false) }
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .bwScreenBackground()
    }

    private func authenticate() {
        isAuthenticating = true
        statusMessage = nil
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Use Face ID to securely access your BuyWise account."
            ) { success, _ in
                Task { @MainActor in
                    isAuthenticating = false
                    onFinished(success)
                }
            }
        } else {
            // No biometrics enrolled (common in Simulator) — provide a graceful demo state.
            Task {
                statusMessage = "Face ID isn't available on this device. Simulating a successful setup for this demo."
                try? await Task.sleep(nanoseconds: 900_000_000)
                isAuthenticating = false
                onFinished(true)
            }
        }
    }
}
