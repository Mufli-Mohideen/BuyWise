import SwiftUI

private enum AppPhase {
    case splash
    case onboarding
    case login
    case faceID
    case main
}

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var phase: AppPhase = .splash
    @State private var showSignUp = false

    var body: some View {
        Group {
            switch phase {
            case .splash:
                SplashView { withAnimation { phase = .onboarding } }
            case .onboarding:
                OnboardingView { withAnimation { phase = .login } }
            case .login:
                LoginView(
                    onSignedIn: { withAnimation { phase = .faceID } },
                    onCreateAccount: { showSignUp = true }
                )
                .sheet(isPresented: $showSignUp) {
                    SignUpView(
                        onAccountCreated: {
                            showSignUp = false
                            withAnimation { phase = .faceID }
                        },
                        onBackToLogin: {}
                    )
                }
            case .faceID:
                FaceIDPromptView { enabled in
                    appState.isFaceIDEnabled = enabled
                    withAnimation { phase = .main }
                }
            case .main:
                RootTabView {
                    withAnimation { phase = .login }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
    }
}
