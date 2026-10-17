import SwiftUI
import MapKit
import Combine

enum HomeRoute: Hashable {
    case identify
    case search
    case nearby
    case alerts
    case category(ProductCategory)
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()
    @State private var activeSheet: IdentifySheet?
    @State private var dealIndex = 0

    private let dealTimer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    private var popularProducts: [Product] {
        Array(ProductCatalog.all.filter(\.isSold).sorted { $0.valueScore.overall > $1.valueScore.overall }.prefix(12))
    }

    private var deals: [(product: Product, previousPrice: Double)] {
        let drops = ProductCatalog.priceDrops
        return Array(drops.prefix(5))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 30) {
                        quickActions
                            .padding(.top, -38)
                        if !deals.isEmpty { dealsCarousel }
                        categories
                        storesNearYou
                        popularProductsSection
                        if !appState.recentlyViewedProducts.isEmpty { recentlyViewedSection }
                        insightSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(edges: .top)
            .bwScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .identify: IdentifyProductView { path.append($0) }
                case .search: SearchView()
                case .nearby: NearbyRetailersView()
                case .alerts: NotificationsInboxView()
                case .category(let category): SearchView(initialCategory: category)
                }
            }
            .identifySheets($activeSheet) { path.append($0) }
            .onReceive(dealTimer) { _ in
                guard deals.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.5)) { dealIndex = (dealIndex + 1) % deals.count }
            }
            .onAppear { LocationProvider.shared.start() }
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: "FF7A1A"), BuyWiseColors.brand, Color(hex: "D94E00")], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle().fill(Color.white.opacity(0.08)).frame(width: 280, height: 280).offset(x: 190, y: -90)
            Circle().fill(Color.white.opacity(0.06)).frame(width: 200, height: 200).offset(x: -80, y: 210)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ProfileAvatarView(size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(timeOfDayGreeting)
                            .font(BuyWiseTypography.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(appState.userName)
                            .font(BuyWiseTypography.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    NotificationBellButton { path.append(HomeRoute.alerts) }
                }

                Text("Compare Abans\n& Celltronics")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 8) {
                    Text("Real prices, price history and value scores for \(ProductCatalog.all.count) top products.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    productCollage
                        .frame(width: 150, height: 118)
                }

                heroSearch

                HStack(spacing: 10) {
                    heroStat(value: PriceFormatter.lkr(appState.totalTrackedSavings), label: "Saved on tracked", symbol: "arrow.down.right")
                    heroStat(value: "\(appState.trackedProducts.count)", label: "Tracking", symbol: "bell.fill")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 62)
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
    }

    private var productCollage: some View {
        ZStack {
            let featured = ProductCatalog.featuredTrio
            collageTile(featured.first { $0.category == .laptops }, size: 76).rotationEffect(.degrees(-10)).offset(x: -34, y: 14)
            collageTile(featured.first { $0.category == .smartphones }, size: 70).rotationEffect(.degrees(9)).offset(x: 30, y: -22)
            collageTile(featured.first { $0.category == .headphones }, size: 72).rotationEffect(.degrees(-4)).offset(x: 36, y: 34)
        }
        .opacity(0.97)
        .accessibilityHidden(true)
    }

    private func collageTile(_ product: Product?, size: CGFloat) -> some View {
        ProductPhoto(product: product)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }

    private var heroSearch: some View {
        HStack(spacing: 10) {
            Button { path.append(HomeRoute.search) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BuyWiseColors.brand)
                    Text("Search phones, laptops, headphones")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(Color(hex: "707070"))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Button { activeSheet = .barcode } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(BuyWiseColors.brand))
            }
            .padding(.trailing, 6)
            .accessibilityLabel("Scan barcode")
        }
        .background(Capsule().fill(Color.white))
        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
    }

    private func heroStat(value: String, label: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BuyWiseColors.brand)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.16)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
    }

    private var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 0) {
            quickAction("Scan\nbarcode", symbol: "barcode.viewfinder") { activeSheet = .barcode }
            quickAction("Scan\nphoto", symbol: "text.viewfinder") { activeSheet = .image }
            quickAction("Paste\nlink", symbol: "link") { activeSheet = .url }
            quickAction("Nearby\nstores", symbol: "map.fill") { path.append(HomeRoute.nearby) }
        }
        .padding(.vertical, 16)
        .bwCard(radius: 22)
        .shadow(color: .black.opacity(0.06), radius: 18, y: 10)
    }

    private func quickAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BuyWiseColors.brand)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BuyWiseColors.brandSoft))
                Text(title)
                    .font(BuyWiseTypography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Deals carousel

    private var dealsCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "On sale now", actionTitle: "See alerts") { path.append(HomeRoute.alerts) }
            TabView(selection: $dealIndex) {
                ForEach(Array(deals.enumerated()), id: \.element.product.id) { index, deal in
                    Button { path.append(deal.product) } label: {
                        DealCard(product: deal.product, previousPrice: deal.previousPrice)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .tag(index)
                    .padding(.horizontal, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 196)

            HStack(spacing: 6) {
                ForEach(deals.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == dealIndex ? BuyWiseColors.brand : BuyWiseColors.border)
                        .frame(width: index == dealIndex ? 18 : 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: dealIndex)
        }
    }

    // MARK: Categories

    private var categories: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Shop by category")
            HStack(spacing: 12) {
                ForEach(ProductCategory.allCases) { category in
                    Button { path.append(HomeRoute.category(category)) } label: {
                        CategoryTile(category: category)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: Stores

    private var storesNearYou: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stores near you", actionTitle: "Open map") { path.append(HomeRoute.nearby) }
            Button { path.append(HomeRoute.nearby) } label: {
                VStack(spacing: 0) {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: LocationProvider.shared.effectiveLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)
                    ))) {
                        Annotation("You", coordinate: LocationProvider.shared.effectiveLocation.coordinate) {
                            Circle().fill(BuyWiseColors.brand).frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                        ForEach(StoreBranches.sortedByDistance().prefix(12)) { branch in
                            Annotation(branch.branchName, coordinate: branch.coordinate) {
                                RetailerMapPin(retailer: branch.retailer)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 150)
                    .allowsHitTesting(false)

                    HStack(spacing: 0) {
                        ForEach(Retailer.allCases) { retailer in
                            if let branch = StoreBranches.nearest(retailer) {
                                HStack(spacing: 10) {
                                    Circle().fill(Color.white).frame(width: 36, height: 36)
                                        .overlay(Image(retailer.logoAssetName).resizable().scaledToFit().padding(6))
                                        .overlay(Circle().strokeBorder(BuyWiseColors.border, lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(branch.branchName)
                                            .font(BuyWiseTypography.captionBold)
                                            .foregroundStyle(BuyWiseColors.textPrimary)
                                            .lineLimit(1)
                                        Text("\(DistanceFormatter.string(LocationProvider.shared.distance(to: branch))) · \(branch.hasHours ? branch.statusText : "Hours not listed")")
                                            .font(BuyWiseTypography.caption)
                                            .foregroundStyle(branch.isOpenNow ? BuyWiseColors.success : BuyWiseColors.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(14)
                }
                .bwCard()
                .clipShape(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: Products

    private var popularProductsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Best value right now", actionTitle: "See all") { path.append(HomeRoute.search) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(popularProducts) { product in
                        NavigationLink(value: product) {
                            ProductCard(
                                product: product,
                                onToggleSave: { appState.toggleSaved(product) },
                                isSaved: appState.isSaved(product)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recently viewed")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(appState.recentlyViewedProducts) { product in
                        NavigationLink(value: product) {
                            CompactProductCard(product: product)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    private var insightSection: some View {
        let best = ProductCatalog.all.max { $0.savings < $1.savings }
        return InsightCard(message: best.map {
            "\($0.lowestListing.retailer.rawValue) is currently \(PriceFormatter.lkr($0.savings)) cheaper than \($0.highestListing.retailer.rawValue) for the \($0.fullName)."
        } ?? "Compare before you buy.")
    }
}

private struct DealCard: View {
    let product: Product
    let previousPrice: Double

    private var percent: Double { (previousPrice - product.startingPrice) / previousPrice * 100 }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "1E1E22"), Color(hex: "2C2C33")], startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle().fill(BuyWiseColors.brand.opacity(0.28)).frame(width: 190, height: 190).blur(radius: 40).offset(x: 40, y: 10)

            ProductPhoto(product: product, padding: 12)
                .frame(width: 140, height: 140)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
                .rotationEffect(.degrees(-5))
                .padding(.trailing, 18)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("\(PriceFormatter.percent(percent)) lower", systemImage: "arrow.down.right")
                    .font(BuyWiseTypography.captionBold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(BuyWiseColors.success))
                    .foregroundStyle(.white)
                Text(product.name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(PriceFormatter.lkr(product.startingPrice))
                        .font(BuyWiseTypography.priceLarge)
                        .foregroundStyle(.white)
                    Text(PriceFormatter.lkr(previousPrice))
                        .font(BuyWiseTypography.caption)
                        .strikethrough()
                        .foregroundStyle(.white.opacity(0.55))
                }
                HStack(spacing: 6) {
                    Text("Best at")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    RetailerLogoView(retailer: product.lowestListing.retailer, height: 13)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CategoryTile: View {
    let category: ProductCategory

    private var hero: Product? { ProductCatalog.featured(category).first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                ProductPhoto(product: hero, category: category, padding: 10)
            }
            .frame(height: 88)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(BuyWiseColors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(category.rawValue)
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(ProductCatalog.products(in: category).count) products")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .bwCard()
    }
}
