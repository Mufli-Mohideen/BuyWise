import Foundation
import UserNotifications

/// Shows backend alerts (delivered to the app over Supabase Realtime) as local notifications.
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

    /// Delivers an alert immediately; the title and message were written by the backend price-drop trigger.
    func showAlert(id: UUID, title: String, message: String, productID: UUID?) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "PRICE_DROP"
        content.threadIdentifier = "price-drops"
        if let productID {
            content.userInfo = ["productID": productID.uuidString]
        }
        let request = UNNotificationRequest(identifier: "alert-\(id.uuidString)", content: content, trigger: nil)
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
