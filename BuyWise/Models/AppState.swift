import Foundation
import Combine
import SwiftUI
import UserNotifications
import Supabase

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System Default"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var databaseValue: String {
        switch self {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        }
    }

    init(databaseValue: String) {
        self = Self.allCases.first { $0.databaseValue == databaseValue } ?? .light
    }

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

extension ShoppingPriority {
    var databaseValue: String {
        switch self {
        case .balanced: return "balanced"
        case .battery: return "battery"
        case .performance: return "performance"
        case .portability: return "portability"
        }
    }

    init(databaseValue: String) {
        self = Self.allCases.first { $0.databaseValue == databaseValue } ?? .balanced
    }
}

struct NotificationSettings: Equatable {
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

        init(databaseValue: String) {
            switch databaseValue {
            case "price_drop": self = .priceDrop
            case "better_price": self = .betterPrice
            case "tracking_started": self = .trackingStarted
            default: self = .tip
            }
        }

        var symbolName: String {
            switch self {
            case .priceDrop: return "arrow.down.right.circle.fill"
            case .betterPrice: return "tag.fill"
            case .trackingStarted: return "bell.badge.fill"
            case .tip: return "lightbulb.fill"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let productID: UUID?
    let title: String
    let message: String
    let date: Date
    var isRead: Bool
}

/// Keeps track of the signed-in user's data and syncs changes with Supabase.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var userID: UUID?

    @Published private(set) var trackedEntries: [UUID: TrackedEntry] = [:]
    @Published private(set) var savedProductIDs: Set<UUID> = []
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var recentlyViewedProductIDs: [UUID] = []
    @Published var appearanceMode: AppearanceMode = .light { didSet { saveProfileIfNeeded() } }
    @Published var isFaceIDEnabled = UserDefaults.standard.bool(forKey: AppState.faceIDKey) {
        didSet {
            UserDefaults.standard.set(isFaceIDEnabled, forKey: Self.faceIDKey)
            saveProfileIfNeeded()
        }
    }
    @Published var notificationSettings = NotificationSettings() { didSet { saveProfileIfNeeded() } }
    @Published private(set) var userName = ""
    @Published private(set) var userEmail = ""
    @Published private(set) var signInMethod = "Email"
    @Published private(set) var profileImageData: Data?
    @Published private(set) var inbox: [AppNotification] = []
    @Published private(set) var lastError: String?

    /// Set to open a product from anywhere (Ex: tapping a notification).
    @Published var deepLinkProduct: Product?
    /// Shows an in-app alert when system notifications aren't available.
    @Published var inAppBanner: AppNotification?
    /// Prompts the user to set a new password after opening a reset link.
    @Published var needsNewPassword = false

    @Published var shoppingPriority: ShoppingPriority = .balanced {
        didSet {
            ValueScoreCalculator.shared.priority = shoppingPriority
            saveProfileIfNeeded()
        }
    }

    var isSignedIn: Bool { userID != nil }

    private static let faceIDKey = "faceIDEnabled"
    private var isApplyingRemoteState = false
    private var alertedNotificationIDs: Set<UUID> = []
    private var alertsChannel: RealtimeChannelV2?
    private var alertsTask: Task<Void, Never>?

    init() {
        NotificationManager.shared.onOpenProduct = { [weak self] id in
            guard let self else { return }
            self.markRead(productID: id)
            self.deepLinkProduct = ProductCatalog.product(id: id)
        }
    }

    // MARK: Session

    /// Restores the saved session if the user is still signed in.
    func restoreSession() async -> Bool {
        // `session` refreshes an expired access token when the refresh token is still valid.
        guard supabase.auth.currentSession != nil, let session = try? await supabase.auth.session else { return false }
        // Demo (anonymous) accounts are no longer supported.
        if session.user.isAnonymous {
            await signOut()
            return false
        }
        await didSignIn(session.user)
        return true
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        await didSignIn(session.user)
    }

    /// Returns false if the user has to confirm their email before signing in.
    func signUp(name: String, email: String, password: String) async throws -> Bool {
        let response = try await supabase.auth.signUp(
            email: email.trimmingCharacters(in: .whitespaces),
            password: password,
            data: ["full_name": .string(name.trimmingCharacters(in: .whitespaces))]
        )
        guard case .session(let session) = response else { return false }
        await didSignIn(session.user)
        return true
    }

    /// Shows Google sign-in in a secure browser sheet. Supabase handles the OAuth exchange.
    func signInWithGoogle() async throws {
        let session = try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseConfig.authCallbackURL
        )
        await didSignIn(session.user)
    }

    func sendPasswordReset(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(
            email.trimmingCharacters(in: .whitespaces),
            redirectTo: SupabaseConfig.passwordResetURL
        )
    }

    /// Signs in from a password reset link. Returns false for any other link.
    func openPasswordResetLink(_ url: URL) async throws -> Bool {
        guard url.scheme == SupabaseConfig.passwordResetURL.scheme, url.host == SupabaseConfig.passwordResetURL.host else {
            return false
        }
        let session = try await supabase.auth.session(from: url)
        await didSignIn(session.user)
        needsNewPassword = true
        return true
    }

    func changePassword(_ password: String) async throws {
        _ = try await supabase.auth.update(user: UserAttributes(password: password))
    }

    func signOut() async {
        await stopListeningForAlerts()
        try? await supabase.auth.signOut()
        clearUserState()
    }

    private func didSignIn(_ user: User) async {
        userID = user.id
        userEmail = user.email ?? ""
        await CatalogStore.shared.loadIfNeeded()
        await loadUserData()
        // Realtime can take a few seconds to connect, so don't block launch or sign-in on it.
        Task { await listenForAlerts(userID: user.id) }
    }

    private func clearUserState() {
        isApplyingRemoteState = true
        userID = nil
        trackedEntries = [:]
        savedProductIDs = []
        recentSearches = []
        recentlyViewedProductIDs = []
        inbox = []
        userName = ""
        userEmail = ""
        signInMethod = "Email"
        profileImageData = nil
        notificationSettings = NotificationSettings()
        shoppingPriority = .balanced
        appearanceMode = .light
        isFaceIDEnabled = false
        inAppBanner = nil
        needsNewPassword = false
        alertedNotificationIDs = []
        isApplyingRemoteState = false
    }

    // MARK: Loading

    func loadUserData() async {
        guard let userID else { return }
        do {
            async let profile: ProfileRow = supabase.from("profiles").select().eq("id", value: userID).single().execute().value
            async let tracked: [TrackedRow] = supabase.from("tracked_products").select().execute().value
            async let saved: [ProductRefRow] = supabase.from("saved_products").select("product_id").execute().value
            async let recent: [RecentlyViewedRow] = supabase.from("recently_viewed").select()
                .order("viewed_at", ascending: false).limit(8).execute().value
            async let searches: [SearchHistoryRow] = supabase.from("search_history").select()
                .order("searched_at", ascending: false).limit(6).execute().value

            let (profileRow, trackedRows, savedRows, recentRows, searchRows) = try await (profile, tracked, saved, recent, searches)
            isApplyingRemoteState = true
            apply(profileRow)
            trackedEntries = Dictionary(uniqueKeysWithValues: trackedRows.map { ($0.productId, Self.entry($0)) })
            savedProductIDs = Set(savedRows.map(\.productId))
            recentlyViewedProductIDs = recentRows.map(\.productId)
            recentSearches = searchRows.map(\.query)
            isApplyingRemoteState = false
            await refreshInbox(alertNew: false)
        } catch {
            isApplyingRemoteState = false
            lastError = "Couldn't load your BuyWise data. Pull to refresh or try again later."
        }
    }

    private func apply(_ profile: ProfileRow) {
        if let fullName = profile.fullName, !fullName.isEmpty {
            userName = fullName
        } else {
            userName = userEmail.components(separatedBy: "@").first ?? ""
        }
        signInMethod = Self.displayName(forProvider: profile.signInMethod)
        appearanceMode = AppearanceMode(databaseValue: profile.appearanceMode)
        shoppingPriority = ShoppingPriority(databaseValue: profile.shoppingPriority)
        isFaceIDEnabled = profile.faceIdEnabled
        notificationSettings = NotificationSettings(
            priceDropAlerts: profile.notifyPriceDrops,
            productTracking: profile.notifyTracking,
            shoppingInsights: profile.notifyInsights
        )
        if let avatar = profile.avatarUrl.flatMap(URL.init(string:)) {
            Task { await loadAvatar(from: avatar) }
        }
    }

    private static func displayName(forProvider provider: String) -> String {
        switch provider {
        case "google": return "Google"
        default: return "Email"
        }
    }

    private static func entry(_ row: TrackedRow) -> TrackedEntry {
        TrackedEntry(
            productID: row.productId,
            previousPrice: row.previousPrice,
            priceAlertsEnabled: row.alertsEnabled,
            dropThresholdPercent: row.dropThresholdPercent,
            dateTracked: row.trackedAt ?? .now
        )
    }

    // MARK: Profile

    private func saveProfileIfNeeded() {
        guard !isApplyingRemoteState, let userID else { return }
        let changes: [String: AnyJSON] = [
            "appearance_mode": .string(appearanceMode.databaseValue),
            "shopping_priority": .string(shoppingPriority.databaseValue),
            "face_id_enabled": .bool(isFaceIDEnabled),
            "notify_price_drops": .bool(notificationSettings.priceDropAlerts),
            "notify_tracking": .bool(notificationSettings.productTracking),
            "notify_insights": .bool(notificationSettings.shoppingInsights)
        ]
        Task { await write { try await supabase.from("profiles").update(changes).eq("id", value: userID).execute() } }
    }

    /// Returns true when the email changed and a confirmation email was sent.
    func updatePersonalInformation(name: String, email: String) async throws -> Bool {
        guard let userID else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        try await supabase.from("profiles").update(["full_name": trimmedName]).eq("id", value: userID).execute()
        userName = trimmedName

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, trimmedEmail.caseInsensitiveCompare(userEmail) != .orderedSame else { return false }
        _ = try await supabase.auth.update(user: UserAttributes(email: trimmedEmail))
        return true
    }

    // MARK: Profile photo

    func setProfileImage(_ data: Data?) {
        profileImageData = data
        guard let userID else { return }
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        Task {
            await write {
                let bucket = supabase.storage.from("avatars")
                var avatarURL: String?
                if let data {
                    try await bucket.upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    // Add a timestamp so other devices load the new photo instead of a cached one.
                    avatarURL = try bucket.getPublicURL(path: path).absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"
                } else {
                    _ = try await bucket.remove(paths: [path])
                }
                try await supabase.from("profiles").update(["avatar_url": avatarURL]).eq("id", value: userID).execute()
            }
        }
    }

    private func loadAvatar(from url: URL) async {
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            profileImageData = data
        }
    }

    // MARK: Alerts (Realtime)

    private func listenForAlerts(userID: UUID) async {
        await stopListeningForAlerts()
        let channel = supabase.channel("alerts-\(userID.uuidString.lowercased())")
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "notifications", filter: .eq("user_id", value: userID))
        alertsTask = Task { [weak self] in
            for await insert in inserts {
                guard insert.record["id"]?.stringValue != nil else { continue }
                await self?.refreshInbox(alertNew: true)
            }
        }
        try? await channel.subscribeWithError()
        alertsChannel = channel
    }

    private func stopListeningForAlerts() async {
        alertsTask?.cancel()
        alertsTask = nil
        if let alertsChannel {
            await supabase.removeChannel(alertsChannel)
        }
        alertsChannel = nil
    }

    /// When `alertNew` is true, new unread price drops also show as a notification or in-app banner.
    func refreshInbox(alertNew: Bool) async {
        guard isSignedIn else { return }
        guard let rows: [NotificationRecord] = try? await supabase.from("notifications").select()
            .order("created_at", ascending: false).limit(50).execute().value else { return }

        let known = Set(inbox.map(\.id))
        inbox = rows.map { row in
            AppNotification(id: row.id, kind: .init(databaseValue: row.kind), productID: row.productId,
                            title: row.title, message: row.message, date: row.createdAt, isRead: row.isRead)
        }

        let fresh = inbox.filter { !known.contains($0.id) }
        for productID in Set(fresh.compactMap(\.productID)) {
            await CatalogStore.shared.refresh(productID: productID)
        }
        guard alertNew else {
            alertedNotificationIDs.formUnion(inbox.map(\.id))
            return
        }
        for alert in fresh where alert.kind == .priceDrop && !alert.isRead && !alertedNotificationIDs.contains(alert.id) {
            alertedNotificationIDs.insert(alert.id)
            await present(alert)
        }
    }

    private func present(_ alert: AppNotification) async {
        let status = await NotificationManager.shared.authorizationStatus()
        if status == .authorized || status == .provisional || status == .ephemeral {
            await NotificationManager.shared.showAlert(id: alert.id, title: alert.title, message: alert.message, productID: alert.productID)
        } else {
            inAppBanner = alert
        }
    }

    // MARK: Demo price feed

    /// A database trigger creates the alert. It arrives over Realtime, with a re-fetch as a fallback.
    func simulatePriceDrop(for product: Product) async {
        if await NotificationManager.shared.authorizationStatus() == .notDetermined {
            await NotificationManager.shared.requestAuthorization()
        }
        await write {
            try await supabase.rpc("simulate_price_drop", params: ProductIDParams(targetProduct: product.id)).execute()
        }
        await CatalogStore.shared.refresh(productID: product.id)
        if trackedEntries[product.id] == nil {
            await reloadTracked()
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await refreshInbox(alertNew: true)
    }

    func resetDemo() async {
        await write { try await supabase.rpc("reset_demo_prices").execute() }
        await CatalogStore.shared.load()
        inAppBanner = nil
    }

    // MARK: Inbox

    var unreadCount: Int { inbox.filter { !$0.isRead }.count }

    func markRead(_ notification: AppNotification) {
        guard let index = inbox.firstIndex(where: { $0.id == notification.id }), !inbox[index].isRead else { return }
        inbox[index].isRead = true
        Task { await write { try await supabase.from("notifications").update(["is_read": true]).eq("id", value: notification.id).execute() } }
    }

    func markRead(productID: UUID) {
        guard inbox.contains(where: { $0.productID == productID && !$0.isRead }) else { return }
        for index in inbox.indices where inbox[index].productID == productID {
            inbox[index].isRead = true
        }
        Task { await write { try await supabase.from("notifications").update(["is_read": true]).eq("product_id", value: productID).execute() } }
    }

    func markAllRead() {
        guard let userID else { return }
        for index in inbox.indices { inbox[index].isRead = true }
        Task { await write { try await supabase.from("notifications").update(["is_read": true]).eq("user_id", value: userID).execute() } }
    }

    func clearInbox() {
        guard let userID else { return }
        inbox.removeAll()
        Task { await write { try await supabase.from("notifications").delete().eq("user_id", value: userID).execute() } }
    }

    // MARK: Tracking

    func isTracked(_ product: Product) -> Bool {
        trackedEntries[product.id] != nil
    }

    func startTracking(_ product: Product, dropThresholdPercent: Double = 5, alertsEnabled: Bool = true) {
        let row = TrackedRow(productId: product.id, previousPrice: product.startingPrice, alertsEnabled: alertsEnabled,
                             dropThresholdPercent: dropThresholdPercent, trackedAt: nil)
        trackedEntries[product.id] = TrackedEntry(productID: product.id, previousPrice: product.startingPrice,
                                                  priceAlertsEnabled: alertsEnabled, dropThresholdPercent: dropThresholdPercent, dateTracked: .now)
        Task {
            await write { try await supabase.from("tracked_products").upsert(row, onConflict: "user_id,product_id").execute() }
            await refreshInbox(alertNew: false)
        }
        if alertsEnabled {
            Task { await NotificationManager.shared.requestAuthorization() }
        }
    }

    func stopTracking(_ product: Product) {
        trackedEntries[product.id] = nil
        Task { await write { try await supabase.from("tracked_products").delete().eq("product_id", value: product.id).execute() } }
    }

    func priceAlertsEnabled(for product: Product) -> Bool {
        trackedEntries[product.id]?.priceAlertsEnabled ?? true
    }

    func setPriceAlerts(_ enabled: Bool, for product: Product) {
        guard trackedEntries[product.id] != nil else { return }
        trackedEntries[product.id]?.priceAlertsEnabled = enabled
        Task {
            await write {
                try await supabase.from("tracked_products").update(["alerts_enabled": enabled]).eq("product_id", value: product.id).execute()
            }
        }
    }

    func previousPrice(for product: Product) -> Double? {
        trackedEntries[product.id]?.previousPrice
    }

    func dropThreshold(for product: Product) -> Double {
        trackedEntries[product.id]?.dropThresholdPercent ?? 5
    }

    private func reloadTracked() async {
        guard let rows: [TrackedRow] = try? await supabase.from("tracked_products").select().execute().value else { return }
        trackedEntries = Dictionary(uniqueKeysWithValues: rows.map { ($0.productId, Self.entry($0)) })
    }

    var trackedProducts: [Product] {
        trackedEntries.values
            .sorted { $0.dateTracked > $1.dateTracked }
            .compactMap { ProductCatalog.product(id: $0.productID) }
    }

    /// How much the user has saved on tracked products since they started tracking them.
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
            Task { await write { try await supabase.from("saved_products").delete().eq("product_id", value: product.id).execute() } }
        } else {
            savedProductIDs.insert(product.id)
            Task {
                await write {
                    try await supabase.from("saved_products")
                        .upsert(ProductRefRow(productId: product.id), onConflict: "user_id,product_id").execute()
                }
            }
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
        let row = SearchHistoryRow(query: trimmed, searchedAt: .now)
        Task { await write { try await supabase.from("search_history").upsert(row, onConflict: "user_id,query_key").execute() } }
    }

    func clearRecentSearches() {
        guard let userID else { return }
        recentSearches.removeAll()
        Task { await write { try await supabase.from("search_history").delete().eq("user_id", value: userID).execute() } }
    }

    // MARK: Recently viewed

    func addRecentlyViewed(_ product: Product) {
        recentlyViewedProductIDs.removeAll { $0 == product.id }
        recentlyViewedProductIDs.insert(product.id, at: 0)
        if recentlyViewedProductIDs.count > 8 {
            recentlyViewedProductIDs.removeLast(recentlyViewedProductIDs.count - 8)
        }
        guard isSignedIn else { return }
        let row = RecentlyViewedRow(productId: product.id, viewedAt: .now)
        Task { await write { try await supabase.from("recently_viewed").upsert(row, onConflict: "user_id,product_id").execute() } }
    }

    var recentlyViewedProducts: [Product] {
        recentlyViewedProductIDs.compactMap { ProductCatalog.product(id: $0) }
    }

    // MARK: Helpers

    /// Reloads the user's data if saving fails, undoing changes already shown on screen.
    private func write(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            lastError = "Couldn't save that change. Check your connection and try again."
            await loadUserData()
        }
    }

    func dismissError() {
        lastError = nil
    }
}
