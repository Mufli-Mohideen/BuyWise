import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    var onLogOut: () -> Void
    @State private var showLogOutConfirmation = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showResetConfirmation = false
    @State private var demoMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                section("Account") {
                    row(title: "Personal Information", symbol: "person.text.rectangle") {
                        PersonalInformationView()
                    }
                    rowDivider
                    row(title: "Security", symbol: "lock.shield") {
                        SecurityView()
                    }
                }

                section("Shopping") {
                    row(title: "Tracked Products", symbol: "bell", detail: "\(appState.trackedProducts.count)") {
                        TrackedView()
                    }
                    rowDivider
                    row(title: "Saved Products", symbol: "heart", detail: "\(appState.savedProducts.count)") {
                        SavedProductsView()
                    }
                    rowDivider
                    row(title: "Alerts", symbol: "bell.and.waves.left.and.right", detail: appState.unreadCount > 0 ? "\(appState.unreadCount) new" : nil) {
                        NotificationsInboxView()
                            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
                    }
                    rowDivider
                    row(title: "Search History", symbol: "clock.arrow.circlepath") {
                        SearchHistoryView()
                    }
                    rowDivider
                    row(title: "Shopping Priorities", symbol: appState.shoppingPriority.symbolName, detail: appState.shoppingPriority.rawValue) {
                        ShoppingPrioritiesView()
                    }
                }

                section("Stores") {
                    row(title: "Nearby Stores", symbol: "map", detail: nearestStoreDetail) {
                        NearbyRetailersView()
                    }
                }

                section("Preferences") {
                    row(title: "Notifications", symbol: "bell.badge") {
                        NotificationsSettingsView()
                    }
                    rowDivider
                    row(title: "Face ID", symbol: "faceid", detail: appState.isFaceIDEnabled ? "Enabled" : "Disabled") {
                        FaceIDSettingsView()
                    }
                    rowDivider
                    row(title: "Appearance", symbol: "circle.righthalf.filled", detail: appState.appearanceMode.rawValue) {
                        AppearanceSettingsView()
                    }
                }

                demoSection

                section("App") {
                    row(title: "About BuyWise", symbol: "info.circle") {
                        LegalDetailView(
                            title: "About BuyWise",
                            bodyText: "BuyWise helps you compare consumer electronics across Celltronics, Abans and Singer, so you can make a confident purchase decision backed by transparent pricing and specification comparisons."
                        )
                    }
                    rowDivider
                    row(title: "Privacy", symbol: "hand.raised") {
                        LegalDetailView(
                            title: "Privacy",
                            bodyText: "Your account, profile, tracked and saved products, search history and alerts are stored in BuyWise's Supabase backend so they follow you across devices, and only you can access them. Barcode scanning and text recognition run on your iPhone. Your location is only used to find nearby Celltronics, Abans and Singer stores and is never stored or shared."
                        )
                    }
                    rowDivider
                    row(title: "Terms", symbol: "doc.text") {
                        LegalDetailView(
                            title: "Terms",
                            bodyText: "BuyWise is a prototype built for evaluation. Prices, listings and store details are a snapshot taken from the Celltronics, Abans and Singer websites and may have changed since. Earlier price history is simulated for demonstration."
                        )
                    }
                }

                Button {
                    showLogOutConfirmation = true
                } label: {
                    Text("Log Out")
                        .font(BuyWiseTypography.headline)
                        .foregroundStyle(BuyWiseColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .bwCard(radius: BuyWiseTheme.controlRadius)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Log out of BuyWise?", isPresented: $showLogOutConfirmation, titleVisibility: .visible) {
            Button("Log Out", role: .destructive, action: onLogOut)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Reset demo prices?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                Task {
                    await appState.resetDemo()
                    flash("Prices restored")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Undoes simulated price drops so every product shows its real Celltronics, Abans and Singer price again.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    appState.setProfileImage(image.resizedForAvatar().jpegData(compressionQuality: 0.85))
                }
                photoItem = nil
            }
        }
        .overlay(alignment: .top) {
            if let demoMessage {
                Label(demoMessage, systemImage: "checkmark.circle.fill")
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(BuyWiseColors.textPrimary))
                    .foregroundStyle(BuyWiseColors.background)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarView(size: 96, ringColor: .white)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                Menu {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                    if appState.profileImageData != nil {
                        Button(role: .destructive) { appState.setProfileImage(nil) } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BuyWiseColors.brand)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .accessibilityLabel("Change profile photo")
            }

            VStack(spacing: 4) {
                Text(appState.userName)
                    .font(BuyWiseTypography.titleXL)
                    .foregroundStyle(.white)
                Text(appState.userEmail)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(.white.opacity(0.85))
                Label(appState.isGuest ? "Guest account" : "Signed in with \(appState.signInMethod)",
                      systemImage: appState.isGuest ? "person.fill" : appState.signInMethod == "Apple ID" ? "apple.logo" : "envelope.fill")
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
            }

            HStack(spacing: 0) {
                stat("\(appState.trackedProducts.count)", "Tracked")
                Divider().frame(height: 28).overlay(Color.white.opacity(0.3))
                stat("\(appState.savedProducts.count)", "Saved")
                Divider().frame(height: 28).overlay(Color.white.opacity(0.3))
                stat(PriceFormatter.lkr(appState.totalTrackedSavings).replacingOccurrences(of: "LKR ", with: ""), "LKR saved")
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.14)))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: "FF7A1A"), BuyWiseColors.brand, Color(hex: "D94E00")], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.white.opacity(0.08)).frame(width: 220).offset(x: 140, y: -90)
                Circle().fill(Color.white.opacity(0.06)).frame(width: 160).offset(x: -150, y: 90)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private var nearestStoreDetail: String? {
        StoreBranches.sortedByDistance().first.map { DistanceFormatter.string(LocationProvider.shared.distance(to: $0)) }
    }

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEMO SCENARIOS")
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                demoButton(
                    title: "Simulate a price drop",
                    subtitle: "Sends a real price-drop alert for a tracked product",
                    symbol: "arrow.down.right.circle.fill"
                ) {
                    guard let product = appState.trackedProducts.first(where: { appState.priceAlertsEnabled(for: $0) })
                            ?? ProductCatalog.featured(.headphones).first else { return }
                    Task {
                        await appState.simulatePriceDrop(for: product)
                        flash("Price dropped on \(product.name)")
                    }
                }
                rowDivider
                demoButton(
                    title: "Reset demo prices",
                    subtitle: "Restore the real scraped retailer prices",
                    symbol: "arrow.counterclockwise.circle.fill"
                ) {
                    showResetConfirmation = true
                }
            }
            .bwCard()
        }
    }

    private func demoButton(title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(BuyWiseColors.brand)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(BuyWiseColors.brandSoft))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text(subtitle)
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func flash(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { demoMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { if demoMessage == message { demoMessage = nil } }
        }
    }

    private var rowDivider: some View {
        Divider().overlay(BuyWiseColors.border).padding(.leading, 58)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .bwCard()
        }
    }

    private func row<Destination: View>(title: String, symbol: String, detail: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(BuyWiseColors.brandSoft)
                        .frame(width: 32, height: 32)
                    Image(systemName: symbol)
                        .font(.system(size: 14))
                        .foregroundStyle(BuyWiseColors.brand)
                }
                Text(title)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BuyWiseColors.textSecondary.opacity(0.6))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }
}
