import SwiftUI

private enum AppPhase {
    case splash
    case onboarding
    case login
    case faceIDSetup
    case locked
    case main
}

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var phase: AppPhase = .splash
    @State private var showSignUp = false
    @State private var splashFinished = false
    @State private var startupPhase: AppPhase?
    @State private var resetLinkError: String?
    @State private var pendingProductID: UUID?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("rememberMe") private var rememberMe = true

    private var catalog: CatalogStore { CatalogStore.shared }

    var body: some View {
        Group {
            switch phase {
            case .splash:
                SplashView {
                    splashFinished = true
                    advanceFromSplash()
                }
                .task { await prepareLaunch() }
            case .onboarding:
                OnboardingView {
                    hasSeenOnboarding = true
                    withAnimation { phase = .login }
                }
            case .login:
                LoginView(
                    onSignedIn: { withAnimation { phase = afterSignIn() } },
                    onCreateAccount: { showSignUp = true }
                )
                .sheet(isPresented: $showSignUp) {
                    SignUpView(
                        onAccountCreated: {
                            showSignUp = false
                            withAnimation { phase = afterSignIn() }
                        },
                        onBackToLogin: {}
                    )
                }
            case .faceIDSetup:
                FaceIDPromptView { enabled in
                    appState.isFaceIDEnabled = enabled
                    withAnimation { phase = .main }
                }
            case .locked:
                FaceIDLockView(
                    onUnlocked: { withAnimation { phase = .main } },
                    onUsePassword: { logOut() }
                )
            case .main:
                if case .failed(let message) = catalog.state, catalog.products.isEmpty {
                    CatalogUnavailableView(message: message) { Task { await catalog.load() } }
                } else {
                    RootTabView(onLogOut: logOut)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
        .onOpenURL { url in
            if let id = widgetProductID(url) {
                pendingProductID = id
                openPendingProduct()
            } else {
                Task { await openPasswordResetLink(url) }
            }
        }
        // A widget link can arrive before sign-in or Face ID, so open it once the main screen shows.
        .onChange(of: phase) { openPendingProduct() }
        .sheet(isPresented: $appState.needsNewPassword) {
            SetNewPasswordView()
        }
        .alert("Reset link didn't work", isPresented: Binding(get: { resetLinkError != nil }, set: { if !$0 { resetLinkError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetLinkError ?? "")
        }
    }

    private func openPasswordResetLink(_ url: URL) async {
        do {
            guard try await appState.openPasswordResetLink(url) else { return }
            withAnimation { phase = .main }
        } catch {
            resetLinkError = "This link has expired or was already used. Request a new one with Forgot password."
        }
    }

    /// The product ID from a widget link, Ex: buywise://product/<id>.
    private func widgetProductID(_ url: URL) -> UUID? {
        guard url.scheme == "buywise", url.host() == "product" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    private func openPendingProduct() {
        guard phase == .main, let id = pendingProductID, let product = ProductCatalog.product(id: id) else { return }
        pendingProductID = nil
        appState.deepLinkProduct = product
    }

    /// Loads the catalogue and restores the saved session while the splash animation plays.
    private func prepareLaunch() async {
        async let catalogLoad: Void = catalog.loadIfNeeded()
        var next: AppPhase
        if !rememberMe {
            await appState.signOut()
            next = hasSeenOnboarding ? .login : .onboarding
        } else if await appState.restoreSession() {
            next = appState.isFaceIDEnabled ? .locked : .main
        } else {
            next = hasSeenOnboarding ? .login : .onboarding
        }
        await catalogLoad
        startupPhase = next
        advanceFromSplash()
    }

    private func advanceFromSplash() {
        guard splashFinished, let startupPhase, phase == .splash else { return }
        withAnimation { phase = startupPhase }
    }

    /// Offer Face ID once per sign-in, unless the account already has it switched on.
    private func afterSignIn() -> AppPhase {
        appState.isFaceIDEnabled ? .main : .faceIDSetup
    }

    private func logOut() {
        Task {
            await appState.signOut()
            withAnimation { phase = .login }
        }
    }
}

/// Shown when the catalogue can't be loaded (e.g. no connection on first launch).
private struct CatalogUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                symbolName: "wifi.exclamationmark",
                title: "Couldn't load prices",
                subtitle: "BuyWise needs a connection to fetch the latest Celltronics, Abans and Singer prices.\n\(message)",
                actionTitle: "Try again",
                action: retry
            )
        }
        .frame(maxHeight: .infinity)
        .bwScreenBackground()
    }
}
