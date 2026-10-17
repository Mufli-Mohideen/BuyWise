import SwiftUI
import LocalAuthentication

struct FaceIDSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isAuthenticating = false
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(BuyWiseColors.brandSoft).frame(width: 84, height: 84)
                        Image(systemName: "faceid")
                            .font(.system(size: 34))
                            .foregroundStyle(BuyWiseColors.brand)
                    }
                    Text(appState.isFaceIDEnabled ? "Face ID is enabled" : "Face ID is disabled")
                        .font(BuyWiseTypography.headline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Use Face ID to securely access your BuyWise account instead of typing a password.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                HStack {
                    Text("Face ID")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Spacer()
                    if appState.isFaceIDEnabled {
                        Label("Enabled", systemImage: "checkmark.circle.fill")
                            .font(BuyWiseTypography.captionBold)
                            .foregroundStyle(BuyWiseColors.success)
                    }
                    Toggle("", isOn: Binding(
                        get: { appState.isFaceIDEnabled },
                        set: { newValue in
                            if newValue {
                                authenticate()
                            } else {
                                appState.isFaceIDEnabled = false
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(BuyWiseColors.brand)
                    .disabled(isAuthenticating)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .bwCard()

                if let statusMessage {
                    Text(statusMessage)
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Face ID")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authenticate() {
        isAuthenticating = true
        statusMessage = nil
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Use Face ID to secure your BuyWise account."
            ) { success, _ in
                Task { @MainActor in
                    isAuthenticating = false
                    appState.isFaceIDEnabled = success
                }
            }
        } else {
            Task {
                statusMessage = "Face ID isn't available on this device. Simulating a successful setup for this demo."
                try? await Task.sleep(nanoseconds: 800_000_000)
                isAuthenticating = false
                appState.isFaceIDEnabled = true
            }
        }
    }
}
