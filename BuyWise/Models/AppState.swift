import Foundation
import Combine
import SwiftUI
import UserNotifications

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System Default"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

struct NotificationSettings {
    var priceDropAlerts = true
    var productTracking = true
    var shoppingInsights = true
}

struct TrackedEntry {
    let productID: UUID
    var previousPrice: Double
    var priceAlertsEnabled: Bool
    var dropThresholdPercent: Double
    let dateTracked: Date
}

struct AppNotification: Identifiable, Hashable {
    enum Kind {
        case priceDrop, betterPrice, trackingStarted, tip

        var symbolName: String {
            switch self {
            case .priceDrop: return "arrow.down.right.circle.fill"
            case .betterPrice: return "tag.fill"
            case .trackingStarted: return "bell.badge.fill"
            case .tip: return "lightbulb.fill"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let productID: UUID?
    let title: String
    let message: String
    let date: Date
    var isRead: Bool
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var trackedEntries: [UUID: TrackedEntry] = [:]
    @Published var savedProductIDs: Set<UUID> = []
    @Published var recentSearches: [String] = ["iPhone 16 Pro", "Sony WH-1000XM5", "MacBook Air"]
    @Published private(set) var recentlyViewedProductIDs: [UUID] = []
    @Published var appearanceMode: AppearanceMode = .light
    @Published var isFaceIDEnabled = false
    @Published var notificationSettings = NotificationSettings()
    @Published var userName: String = "Mufli"
    @Published var userEmail: String = "mufli@buywise.app"
    @Published var signInMethod: String = "Email"
    @Published private(set) var profileImageData: Data?
    @Published private(set) var inbox: [AppNotification] = []

    /// Set to open a product from anywhere (e.g. tapping a notification).
    @Published var deepLinkProduct: Product?
    /// In-app banner for alerts when system notifications aren't allowed.
    @Published var inAppBanner: AppNotification?

    @Published var shoppingPriority: ShoppingPriority = .balanced {
        didSet { ValueScoreCalculator.shared.priority = shoppingPriority }
    }

    init() {
        seedDemoData()
        profileImageData = try? Data(contentsOf: Self.profileImageURL)
        NotificationManager.shared.onOpenProduct = { [weak self] id in
            guard let self else { return }
            self.markRead(productID: id)
            self.deepLinkProduct = ProductCatalog.all.first { $0.id == id }
        }
    }

    // MARK: Demo data

    private func seedDemoData() {
        let calendar = Calendar.current
        let day: (Int) -> Date = { calendar.date(byAdding: .day, value: -$0, to: .now) ?? .now }

        trackedEntries = [
            ProductCatalog.sonyWH1000XM5.id: TrackedEntry(productID: ProductCatalog.sonyWH1000XM5.id, previousPrice: 94_990, priceAlertsEnabled: true, dropThresholdPercent: 5, dateTracked: day(6)),
            ProductCatalog.iPhone16Pro.id: TrackedEntry(productID: ProductCatalog.iPhone16Pro.id, previousPrice: 359_900, priceAlertsEnabled: true, dropThresholdPercent: 5, dateTracked: day(3)),
            ProductCatalog.macBookAirM3.id: TrackedEntry(productID: ProductCatalog.macBookAirM3.id, previousPrice: 389_900, priceAlertsEnabled: false, dropThresholdPercent: 10, dateTracked: day(1))
        ]

        savedProductIDs = [ProductCatalog.boseQCUltra.id, ProductCatalog.galaxyS25.id, ProductCatalog.asusVivobook15.id]
        recentlyViewedProductIDs = [ProductCatalog.xiaomi14TPro.id, ProductCatalog.jblLive770NC.id, ProductCatalog.pixel9.id]

        let hour: (Double) -> Date = { Date().addingTimeInterval(-$0 * 3600) }
        inbox = [
            AppNotification(kind: .priceDrop, productID: ProductCatalog.sonyWH1000XM5.id,
                            title: "Price dropped on WH-1000XM5",
                            message: "Now LKR 89,990 at Abans, 5.3% lower. You save LKR 5,000.",
                            date: hour(20), isRead: false),
            AppNotification(kind: .betterPrice, productID: ProductCatalog.jblLive770NC.id,
                            title: "Better price at Abans",
                            message: "JBL Live 770NC is LKR 2,000 cheaper at Abans than Singer.",
                            date: hour(46), isRead: false),
            AppNotification(kind: .trackingStarted, productID: ProductCatalog.macBookAirM3.id,
                            title: "Tracking MacBook Air M3",
                            message: "We'll let you know when the price drops by 10% or more.",
                            date: hour(24), isRead: true),
            AppNotification(kind: .tip, productID: nil,
                            title: "Compare before you buy",
                            message: "Singer and Abans prices can differ by thousands of rupees on the same model.",
                            date: hour(96), isRead: true)
        ].sorted { $0.date > $1.date }
    }

    func resetDemo() {
        PriceBook.shared.reset()
        seedDemoData()
        inAppBanner = nil
    }

    // MARK: Price-drop scenario

    /// Mock-API price change: drops the product's lowest retailer price and raises an alert,
    /// exactly as a real price feed update would.
    func simulatePriceDrop(for product: Product) async {
        let listing = product.lowestListing
        let oldPrice = listing.price
        let percent = Double.random(in: 0.06...0.09)
        let newPrice = max(((oldPrice * (1 - percent)) / 1000).rounded(.down) * 1000 - 10, 990)

        PriceBook.shared.setPrice(newPrice, for: product, at: listing.retailer)

        if trackedEntries[product.id] == nil {
            trackedEntries[product.id] = TrackedEntry(productID: product.id, previousPrice: oldPrice, priceAlertsEnabled: true, dropThresholdPercent: 5, dateTracked: .now)
        } else {
            trackedEntries[product.id]?.previousPrice = oldPrice
        }

        let dropPercent = (oldPrice - newPrice) / oldPrice * 100
        let alert = AppNotification(
            kind: .priceDrop,
            productID: product.id,
            title: "Price dropped on \(product.name)",
            message: "Now \(PriceFormatter.lkr(newPrice)) at \(listing.retailer.rawValue), \(PriceFormatter.percent(dropPercent)) lower. You save \(PriceFormatter.lkr(oldPrice - newPrice)).",
            date: .now,
            isRead: false
        )
        inbox.insert(alert, at: 0)

        guard notificationSettings.priceDropAlerts, priceAlertsEnabled(for: product) else { return }

        let status = await NotificationManager.shared.authorizationStatus()
        let allowed: Bool
        if status == .notDetermined {
            allowed = await NotificationManager.shared.requestAuthorization()
        } else {
            allowed = status == .authorized || status == .provisional || status == .ephemeral
        }

        if allowed {
            await NotificationManager.shared.schedulePriceDrop(
                productID: product.id, productName: product.name,
                newPrice: newPrice, oldPrice: oldPrice, retailer: listing.retailer
            )
        } else {
            try? await Task.sleep(nanoseconds: 800_000_000)
            inAppBanner = alert
        }
    }

    // MARK: Inbox

    var unreadCount: Int { inbox.filter { !$0.isRead }.count }

    func markRead(_ notification: AppNotification) {
        guard let index = inbox.firstIndex(where: { $0.id == notification.id }) else { return }
        inbox[index].isRead = true
    }

    func markRead(productID: UUID) {
        for index in inbox.indices where inbox[index].productID == productID {
            inbox[index].isRead = true
        }
    }

    func markAllRead() {
        for index in inbox.indices { inbox[index].isRead = true }
    }

    func clearInbox() {
        inbox.removeAll()
    }

    // MARK: Profile photo

    private static var profileImageURL: URL {
        URL.documentsDirectory.appending(path: "profile-photo.jpg")
    }

    func setProfileImage(_ data: Data?) {
        profileImageData = data
        if let data {
            try? data.write(to: Self.profileImageURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.profileImageURL)
        }
    }

    // MARK: Tracking

    func isTracked(_ product: Product) -> Bool {
        trackedEntries[product.id] != nil
    }

    func startTracking(_ product: Product, dropThresholdPercent: Double = 5, alertsEnabled: Bool = true) {
        trackedEntries[product.id] = TrackedEntry(
            productID: product.id,
            previousPrice: product.startingPrice,
            priceAlertsEnabled: alertsEnabled,
            dropThresholdPercent: dropThresholdPercent,
            dateTracked: .now
        )
        inbox.insert(AppNotification(
            kind: .trackingStarted, productID: product.id,
            title: "Tracking \(product.name)",
            message: "We'll let you know when the price drops by \(Int(dropThresholdPercent))% or more.",
            date: .now, isRead: true
        ), at: 0)
        if alertsEnabled {
            Task { await NotificationManager.shared.requestAuthorization() }
        }
    }

    func stopTracking(_ product: Product) {
        trackedEntries[product.id] = nil
    }

    func priceAlertsEnabled(for product: Product) -> Bool {
        trackedEntries[product.id]?.priceAlertsEnabled ?? true
    }

    func setPriceAlerts(_ enabled: Bool, for product: Product) {
        trackedEntries[product.id]?.priceAlertsEnabled = enabled
    }

    func previousPrice(for product: Product) -> Double? {
        trackedEntries[product.id]?.previousPrice
    }

    func dropThreshold(for product: Product) -> Double {
        trackedEntries[product.id]?.dropThresholdPercent ?? 5
    }

    var trackedProducts: [Product] {
        ProductCatalog.all
            .filter { trackedEntries[$0.id] != nil }
            .sorted { (trackedEntries[$0.id]?.dateTracked ?? .distantPast) > (trackedEntries[$1.id]?.dateTracked ?? .distantPast) }
    }

    /// Total saved across tracked products versus the price when tracking started.
    var totalTrackedSavings: Double {
        trackedProducts.reduce(0) { total, product in
            total + max(0, (previousPrice(for: product) ?? product.startingPrice) - product.startingPrice)
        }
    }

    // MARK: Saved products

    func isSaved(_ product: Product) -> Bool {
        savedProductIDs.contains(product.id)
    }

    func toggleSaved(_ product: Product) {
        if savedProductIDs.contains(product.id) {
            savedProductIDs.remove(product.id)
        } else {
            savedProductIDs.insert(product.id)
        }
    }

    var savedProducts: [Product] {
        ProductCatalog.all.filter { savedProductIDs.contains($0.id) }
    }

    // MARK: Search history

    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 6 {
            recentSearches.removeLast(recentSearches.count - 6)
        }
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
    }

    // MARK: Recently viewed

    func addRecentlyViewed(_ product: Product) {
        recentlyViewedProductIDs.removeAll { $0 == product.id }
        recentlyViewedProductIDs.insert(product.id, at: 0)
        if recentlyViewedProductIDs.count > 8 {
            recentlyViewedProductIDs.removeLast(recentlyViewedProductIDs.count - 8)
        }
    }

    var recentlyViewedProducts: [Product] {
        recentlyViewedProductIDs.compactMap { id in ProductCatalog.all.first { $0.id == id } }
    }
}

extension ProductCatalog {
    /// Products whose current price is below their price a month ago, biggest drop first.
    static var priceDrops: [(product: Product, previousPrice: Double)] {
        all.compactMap { product -> (Product, Double)? in
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            guard let earlier = product.priceHistory.last(where: { $0.date <= cutoff })?.price,
                  earlier > product.startingPrice else { return nil }
            return (product, earlier)
        }
        .sorted { ($0.1 - $0.0.startingPrice) / $0.1 > ($1.1 - $1.0.startingPrice) / $1.1 }
    }
}
