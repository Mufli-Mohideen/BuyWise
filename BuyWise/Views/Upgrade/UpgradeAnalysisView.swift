import SwiftUI

/// Step 1: choose the product you own and the one you're considering.
struct UpgradeAnalysisView: View {
    @State private var category: ProductCategory
    @State private var current: Product
    @State private var candidate: Product
    @State private var showResult = false

    init(preselectedNew: Product? = nil) {
        let category = preselectedNew?.category ?? .smartphones
        let candidate = preselectedNew ?? Self.defaultCandidate(for: category)
        _category = State(initialValue: category)
        _candidate = State(initialValue: candidate)
        _current = State(initialValue: Self.defaultOwned(for: category, excluding: candidate))
    }

    private var ownable: [Product] { ProductCatalog.ownableProducts.filter { $0.category == category } }
    private var buyable: [Product] { ProductCatalog.all.filter { $0.category == category } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upgrade analysis")
                        .font(BuyWiseTypography.titleXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Compare what you own with what you're considering. We show the numbers; the decision is yours.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }

                categorySelector

                VStack(spacing: 0) {
                    ProductChoiceCard(role: "I own", product: current, options: ownable, exclude: candidate) { current = $0 }
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(BuyWiseColors.brand))
                        .overlay(Circle().strokeBorder(BuyWiseColors.background, lineWidth: 3))
                        .padding(.vertical, -10)
                        .zIndex(1)
                    ProductChoiceCard(role: "I'm considering", product: candidate, options: buyable, exclude: current) { candidate = $0 }
                }

                PrimaryButton(title: "Analyse upgrade", symbolName: "chart.bar.xaxis", isEnabled: current.id != candidate.id) {
                    showResult = true
                }

                Label("Older models no longer sold by Celltronics or Abans can still be chosen as the product you own.", systemImage: "info.circle")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Upgrade analysis")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResult) {
            UpgradeResultView(analysis: UpgradeAnalyzer.analyze(current: current, new: candidate))
        }
        .onChange(of: category) { _, newCategory in
            candidate = Self.defaultCandidate(for: newCategory)
            current = Self.defaultOwned(for: newCategory, excluding: candidate)
        }
    }

    private var categorySelector: some View {
        HStack(spacing: 8) {
            ForEach(ProductCategory.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { category = option }
                } label: {
                    Text(option.rawValue)
                        .font(BuyWiseTypography.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(category == option ? BuyWiseColors.brand : BuyWiseColors.surfaceSecondary))
                        .foregroundStyle(category == option ? .white : BuyWiseColors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Prefer a newer model from the same brand as the reference device people are likely to own.
    private static func defaultCandidate(for category: ProductCategory) -> Product {
        let owned = ProductCatalog.referenceProducts.first { $0.category == category }
        let sold = ProductCatalog.products(in: category).filter(\.isSold)
        return sold.filter { $0.brand == owned?.brand }.max { $0.valueScore.overall < $1.valueScore.overall }
            ?? ProductCatalog.featured(category).first
            ?? sold.first
            ?? ProductCatalog.ownableProducts.first { $0.category == category }!
    }

    /// Prefer an older reference model of the same category, so the default comparison is a real upgrade.
    private static func defaultOwned(for category: ProductCategory, excluding candidate: Product) -> Product {
        let pool = ProductCatalog.referenceProducts + ProductCatalog.all
        return pool.first { $0.category == category && $0.brand == candidate.brand && $0.id != candidate.id }
            ?? pool.first { $0.category == category && $0.id != candidate.id }
            ?? candidate
    }
}

private struct ProductChoiceCard: View {
    let role: String
    let product: Product
    let options: [Product]
    let exclude: Product
    let onSelect: (Product) -> Void

    var body: some View {
        Menu {
            ForEach(options.filter { $0.id != exclude.id }) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option.isSold ? option.fullName : "\(option.fullName) (no longer sold)")
                }
            }
        } label: {
            HStack(spacing: 14) {
                ProductImageView(product: product, cornerRadius: BuyWiseTheme.smallRadius)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.uppercased())
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(BuyWiseColors.brand)
                    Text(product.fullName)
                        .font(BuyWiseTypography.headline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(product.isSold ? "From \(PriceFormatter.lkr(product.startingPrice))" : "No longer sold")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .padding(14)
            .bwCard()
        }
        .accessibilityLabel("\(role): \(product.fullName). Double tap to change.")
    }
}
