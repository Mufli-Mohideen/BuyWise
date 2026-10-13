import Foundation
import UserNotifications

/// Local price-drop notifications (no server push, per the MVP scope).
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Called when the user taps a notification; receives the product id.
    var onOpenProduct: ((UUID) -> Void)?

    private var center: UNUserNotificationCenter { .current() }

    func configure() {
        center.delegate = self
        let view = UNNotificationAction(identifier: "VIEW_PRODUCT", title: "View product", options: [.foreground])
        let category = UNNotificationCategory(identifier: "PRICE_DROP", actions: [view], intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedulePriceDrop(productID: UUID, productName: String, newPrice: Double, oldPrice: Double, retailer: Retailer, delay: TimeInterval = 1.5) async {
        let content = UNMutableNotificationContent()
        content.title = "Price dropped on \(productName)"
        let percent = (oldPrice - newPrice) / oldPrice * 100
        content.body = "Now \(PriceFormatter.lkr(newPrice)) at \(retailer.rawValue), \(PriceFormatter.percent(percent)) lower. You save \(PriceFormatter.lkr(oldPrice - newPrice))."
        content.sound = .default
        content.categoryIdentifier = "PRICE_DROP"
        content.userInfo = ["productID": productID.uuidString]
        content.threadIdentifier = "price-drops"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: "price-drop-\(productID.uuidString)-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    // Show the banner even while BuyWise is open, so the alert is visible in the demo.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let idString = response.notification.request.content.userInfo["productID"] as? String,
              let id = UUID(uuidString: idString) else { return }
        await MainActor.run {
            NotificationManager.shared.onOpenProduct?(id)
        }
    }
}
