import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                permissionCard
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Price Drop Alerts",
                        subtitle: "Get notified when a tracked product drops in price.",
                        symbol: "arrow.down.circle",
                        isOn: $appState.notificationSettings.priceDropAlerts
                    )
                    Divider().overlay(BuyWiseColors.border).padding(.leading, 58)
                    toggleRow(
                        title: "Product Tracking",
                        subtitle: "Updates about products you're tracking.",
                        symbol: "bell",
                        isOn: $appState.notificationSettings.productTracking
                    )
                    Divider().overlay(BuyWiseColors.border).padding(.leading, 58)
                    toggleRow(
                        title: "Shopping Insights",
                        subtitle: "Tips and value comparisons from BuyWise.",
                        symbol: "lightbulb",
                        isOn: $appState.notificationSettings.shoppingInsights
                    )
                }
                .bwCard()
            }
            .padding(20)
        }
        .bwScreenBackground()
        .task { status = await NotificationManager.shared.authorizationStatus() }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isAllowed: Bool { status == .authorized || status == .provisional || status == .ephemeral }

    private var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isAllowed ? "checkmark.seal.fill" : "bell.slash.fill")
                .font(.system(size: 20))
                .foregroundStyle(isAllowed ? BuyWiseColors.success : BuyWiseColors.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(isAllowed ? "Notifications are on" : "Notifications are off")
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(isAllowed ? "Price-drop alerts will appear on your lock screen." : "Turn them on to hear about price drops right away.")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            Spacer()
            if !isAllowed {
                Button(status == .denied ? "Settings" : "Turn on") {
                    Task {
                        if status == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                            await UIApplication.shared.open(url)
                        } else {
                            await NotificationManager.shared.requestAuthorization()
                        }
                        status = await NotificationManager.shared.authorizationStatus()
                    }
                }
                .font(BuyWiseTypography.captionBold)
                .buttonStyle(.borderedProminent)
                .tint(BuyWiseColors.brand)
            }
        }
        .padding(14)
        .bwCard()
    }

    private func toggleRow(title: String, subtitle: String, symbol: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(BuyWiseColors.brandSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(BuyWiseColors.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text(subtitle)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(BuyWiseColors.brand)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }
}
