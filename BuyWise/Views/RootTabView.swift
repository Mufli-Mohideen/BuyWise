import SwiftUI

struct RootTabView: View {
    var onLogOut: () -> Void
    @EnvironmentObject private var appState: AppState

    init(onLogOut: @escaping () -> Void) {
        self.onLogOut = onLogOut
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "1C1C1E") : UIColor(hex: "FFFFFF")
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                SearchView()
                    .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                CompareView()
                    .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            }
            .tabItem { Label("Compare", systemImage: "arrow.left.arrow.right.circle.fill") }

            NavigationStack {
                TrackedView()
            }
            .tabItem { Label("Tracked", systemImage: "bell.fill") }
            .badge(appState.unreadCount)

            NavigationStack {
                ProfileView(onLogOut: onLogOut)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(BuyWiseColors.brand)
        .overlay(alignment: .top) {
            if let banner = appState.inAppBanner {
                InAppAlertBanner(notification: banner) {
                    appState.inAppBanner = nil
                    if let id = banner.productID {
                        appState.markRead(productID: id)
                        appState.deepLinkProduct = ProductCatalog.all.first { $0.id == id }
                    }
                } onDismiss: {
                    appState.inAppBanner = nil
                }
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: appState.inAppBanner)
        .sheet(item: $appState.deepLinkProduct) { product in
            NavigationStack {
                ProductDetailView(product: product)
                    .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { appState.deepLinkProduct = nil }
                        }
                    }
            }
        }
    }
}

private struct InAppAlertBanner: View {
    let notification: AppNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image("BuyWiseLogoMark")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(BuyWiseTypography.subheadline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text(notification.message)
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .gesture(DragGesture(minimumDistance: 10).onEnded { value in
            if value.translation.height < 0 { onDismiss() }
        })
        .task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            onDismiss()
        }
    }
}
