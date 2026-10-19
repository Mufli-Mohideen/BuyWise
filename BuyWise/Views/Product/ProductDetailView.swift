import SwiftUI

struct ProductDetailView: View {
    let product: Product

    @EnvironmentObject private var appState: AppState
    @State private var showTrackingSheet = false
    @State private var toastMessage: String?

    private var isTracked: Bool { appState.isTracked(product) }
    private var isSaved: Bool { appState.isSaved(product) }
    private var alternatives: [Product] { ProductCatalog.alternatives(for: product) }
    private var dropSinceTracking: Double? {
        guard let previous = appState.previousPrice(for: product), previous > product.startingPrice else { return nil }
        return previous - product.startingPrice
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    priceSummary
                    TrackingButton(isTracking: isTracked) {
                        if isTracked {
                            appState.stopTracking(product)
                            showToast("Stopped tracking")
                        } else {
                            showTrackingSheet = true
                        }
                    }
                    retailerComparison
                    if product.listings.count > 1 {
                        ListingMatchCard(product: product, match: product.listingMatch)
                    }
                    ValueScoreCard(valueScore: product.valueScore)
                    PriceHistoryChart(fullHistory: product.priceHistory)
                    UpgradeAnalysisEntryCard(preselectedNew: product)
                    buyInStore
                    specifications
                    alternativesSection
                }
                .padding(20)
            }

            if let toastMessage {
                Label(toastMessage, systemImage: "checkmark.circle.fill")
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(BuyWiseColors.textPrimary))
                    .foregroundStyle(BuyWiseColors.background)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .bwScreenBackground()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    appState.toggleSaved(product)
                    showToast(appState.isSaved(product) ? "Saved to your list" : "Removed from saved")
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(isSaved ? BuyWiseColors.brand : BuyWiseColors.textSecondary)
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save product")

                Menu {
                    Button {
                        Task { await appState.simulatePriceDrop(for: product) }
                    } label: {
                        Label("Simulate a price drop", systemImage: "arrow.down.right.circle")
                    }
                    if let link = product.lowestListing.url {
                        ShareLink(item: link) {
                            Label("Share product", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showTrackingSheet) {
            TrackingSheetView(product: product) { threshold, alertsEnabled in
                appState.startTracking(product, dropThresholdPercent: threshold, alertsEnabled: alertsEnabled)
                showToast("Price tracking enabled")
            }
        }
        .onAppear { appState.addRecentlyViewed(product) }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toastMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { if toastMessage == message { toastMessage = nil } }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.95)], startPoint: .top, endPoint: .bottom))
                Circle()
                    .fill(BuyWiseColors.brand.opacity(0.10))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                ProductPhoto(product: product, padding: 24)
                    .accessibilityLabel("\(product.fullName) product photo")
            }
            .frame(height: 260)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(BuyWiseColors.border, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Text(product.category.rawValue)
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white))
                    .foregroundStyle(BuyWiseColors.brand)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .padding(14)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(product.brand.uppercased())
                    .font(BuyWiseTypography.captionBold)
                    .tracking(1)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Text(product.name)
                    .font(BuyWiseTypography.display)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                if !product.tagline.isEmpty {
                    Text(product.tagline)
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                } else if !product.keySpec.isEmpty {
                    Text(product.keySpec)
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }

            HStack(spacing: 12) {
                if let rating = product.rating {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: starSymbol(for: index, rating: rating))
                                .font(.system(size: 13))
                                .foregroundStyle(BuyWiseColors.brand)
                        }
                    }
                    Text(String(format: "%.1f", rating))
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                ValueScoreBadge(score: product.valueScore.overall)
                Spacer()
                DemoDataBadge(text: "Retailer prices")
            }
        }
    }

    private func starSymbol(for index: Int, rating: Double) -> String {
        let filled = Double(index) + 1
        if rating >= filled { return "star.fill" }
        if rating >= filled - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    private var priceSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best price")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    Text(PriceFormatter.lkr(product.startingPrice))
                        .font(BuyWiseTypography.priceXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    RetailerLogoView(retailer: product.lowestListing.retailer, height: 16)
                    if product.savings > 0 {
                        Text("Save \(PriceFormatter.lkr(product.savings))")
                            .font(BuyWiseTypography.captionBold)
                            .foregroundStyle(BuyWiseColors.success)
                    }
                }
            }

            if let drop = dropSinceTracking {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(BuyWiseColors.success)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Price dropped \(PriceFormatter.lkr(drop))")
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Text("since you started tracking this product")
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(BuyWiseColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BuyWiseColors.success.opacity(0.1)))
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .padding(16)
        .bwCard()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: product.startingPrice)
    }

    // MARK: Sections

    private var retailerComparison: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Compare retailers")
            // Side by side when the prices fit, otherwise one row per retailer (three stores, seven-digit prices).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(product.listings) { listing in
                        RetailerPriceCard(listing: listing, isLowest: listing.id == product.lowestListing.id)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(product.listings) { listing in
                        RetailerPriceCard(listing: listing, isLowest: listing.id == product.lowestListing.id, isCompact: true)
                    }
                }
            }
            if product.listings.count == 1, let only = product.listings.first {
                Label("Only \(only.retailer.rawValue) stocks this model right now.", systemImage: "info.circle")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
        }
    }

    private var buyInStore: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Buy in store", subtitle: "Nearest branches to you")
            VStack(spacing: 10) {
                ForEach(Retailer.allCases) { retailer in
                    if let branch = StoreBranches.nearest(retailer), let listing = product.listing(for: retailer) {
                        NavigationLink {
                            NearbyRetailersView(initialRetailer: retailer, focusProduct: product)
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color.white).frame(width: 42, height: 42)
                                    .overlay(Image(retailer.logoAssetName).resizable().scaledToFit().padding(7))
                                    .overlay(Circle().strokeBorder(BuyWiseColors.border, lineWidth: 1))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(branch.branchName)
                                        .font(BuyWiseTypography.subheadline)
                                        .foregroundStyle(BuyWiseColors.textPrimary)
                                    Text("\(DistanceFormatter.string(LocationProvider.shared.distance(to: branch))) · \(branch.shortHoursText)")
                                        .font(BuyWiseTypography.caption)
                                        .foregroundStyle(branch.hasHours && !branch.isOpenNow ? BuyWiseColors.error : BuyWiseColors.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(PriceFormatter.lkr(listing.price))
                                        .font(BuyWiseTypography.priceSmall)
                                        .foregroundStyle(BuyWiseColors.textPrimary)
                                    Image(systemName: "map")
                                        .font(.system(size: 12))
                                        .foregroundStyle(BuyWiseColors.brand)
                                }
                            }
                            .padding(14)
                            .bwCard(radius: BuyWiseTheme.controlRadius)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var specifications: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Specifications")
            VStack(spacing: 8) {
                ForEach(product.specifications) { spec in
                    SpecificationRow(specification: spec)
                }
            }
        }
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Similar \(product.category.rawValue.lowercased())", subtitle: "Ranked by BuyWise Value Score")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(alternatives) { alternative in
                        NavigationLink(value: alternative) {
                            CompactProductCard(product: alternative)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }
}
