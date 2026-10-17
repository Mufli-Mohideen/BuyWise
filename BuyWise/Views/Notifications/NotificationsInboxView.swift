import SwiftUI
import UserNotifications

struct NotificationsInboxView: View {
    @EnvironmentObject private var appState: AppState
    @State private var authorization: UNAuthorizationStatus = .authorized

    private var today: [AppNotification] { appState.inbox.filter { Calendar.current.isDateInToday($0.date) } }
    private var earlier: [AppNotification] { appState.inbox.filter { !Calendar.current.isDateInToday($0.date) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if authorization == .denied || authorization == .notDetermined {
                    permissionBanner
                }

                if appState.inbox.isEmpty {
                    EmptyStateView(symbolName: "bell.slash", title: "No alerts yet", subtitle: "Track a product and we'll alert you when its price drops.")
                } else {
                    if !today.isEmpty { section("Today", today) }
                    if !earlier.isEmpty { section("Earlier", earlier) }
                }
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appState.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") { withAnimation { appState.markAllRead() } }
                        .tint(BuyWiseColors.brand)
                }
            }
        }
        .task { authorization = await NotificationManager.shared.authorizationStatus() }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 18))
                .foregroundStyle(BuyWiseColors.brand)
                .frame(width: 36, height: 36)
                .background(Circle().fill(BuyWiseColors.brandSoft))
            VStack(alignment: .leading, spacing: 6) {
                Text("Get alerts on your lock screen")
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text("Allow notifications so price drops reach you even when BuyWise is closed.")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Button(authorization == .denied ? "Open Settings" : "Allow notifications") {
                    Task {
                        if authorization == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                            await UIApplication.shared.open(url)
                        } else {
                            await NotificationManager.shared.requestAuthorization()
                            authorization = await NotificationManager.shared.authorizationStatus()
                        }
                    }
                }
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.brand)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .bwCard()
    }

    private func section(_ title: String, _ items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
            VStack(spacing: 10) {
                ForEach(items) { item in
                    if let product = item.productID.flatMap({ ProductCatalog.product(id: $0) }) {
                        NavigationLink(value: product) {
                            NotificationRow(notification: item, product: product)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded { appState.markRead(item) })
                    } else {
                        NotificationRow(notification: item, product: nil)
                            .onTapGesture { appState.markRead(item) }
                    }
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let product: Product?

    private var tint: Color {
        switch notification.kind {
        case .priceDrop: return BuyWiseColors.success
        case .betterPrice, .trackingStarted: return BuyWiseColors.brand
        case .tip: return BuyWiseColors.warning
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let product {
                    ProductImageView(product: product, cornerRadius: 10)
                        .frame(width: 52, height: 52)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BuyWiseColors.brandSoft)
                        .frame(width: 52, height: 52)
                        .overlay(Image("BuyWiseLogoMark").resizable().scaledToFit().padding(12))
                }
                Image(systemName: notification.kind.symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(tint))
                    .overlay(Circle().strokeBorder(BuyWiseColors.surface, lineWidth: 2))
                    .offset(x: 6, y: 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(BuyWiseTypography.subheadline)
                        .fontWeight(notification.isRead ? .medium : .semibold)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(notification.date, format: .relative(presentation: .named))
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                Text(notification.message)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            if !notification.isRead {
                Circle().fill(BuyWiseColors.brand).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .fill(notification.isRead ? BuyWiseColors.surface : BuyWiseColors.brandSoft.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                .strokeBorder(BuyWiseColors.border, lineWidth: 1)
        )
    }
}
