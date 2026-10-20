import SwiftUI

struct CompareView: View {
    @State private var selectedCategory: ProductCategory
    @State private var productA: Product
    @State private var productB: Product
    @State private var summary: ProductSummarizer.Summary?

    init() {
        let category = ProductCategory.headphones
        let (first, second) = Self.defaultPair(for: category)
        _selectedCategory = State(initialValue: category)
        _productA = State(initialValue: first)
        _productB = State(initialValue: second)
    }

    private var categoryProducts: [Product] {
        ProductCatalog.products(in: selectedCategory).filter(\.isSold)
    }

    /// The two best-value products in the category that more than one retailer stocks.
    private static func defaultPair(for category: ProductCategory) -> (Product, Product) {
        let featured = ProductCatalog.featured(category, count: 2)
        let pool = featured.count == 2
            ? featured
            : ProductCatalog.products(in: category).filter(\.isSold) + ProductCatalog.referenceProducts.filter { $0.category == category }
        return (pool[0], pool.count > 1 ? pool[1] : pool[0])
    }

    private var commonSpecLabels: [String] {
        let labelsB = Set(productB.specifications.map(\.label))
        return productA.specifications.map(\.label).filter { labelsB.contains($0) }
    }

    private var priceWinner: ComparisonWinner {
        let a = productA.startingPrice, b = productB.startingPrice
        return a == b ? .none : (a < b ? .first : .second)
    }

    private var valueWinner: ComparisonWinner {
        let a = productA.valueScore.overall, b = productB.valueScore.overall
        return a == b ? .none : (a > b ? .first : .second)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Products")
                        .font(BuyWiseTypography.titleXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text("Products can only be compared within the same category.")
                        .font(BuyWiseTypography.body)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                UpgradeAnalysisEntryCard()

                CategoryPicker(selection: $selectedCategory)
                selectors

                VStack(spacing: 12) {
                    ComparisonRow(
                        title: "Price",
                        valueA: PriceFormatter.lkr(productA.startingPrice),
                        valueB: PriceFormatter.lkr(productB.startingPrice),
                        winner: priceWinner
                    )

                    ForEach(commonSpecLabels, id: \.self) { label in
                        ComparisonRow(
                            title: label,
                            valueA: productA.specValue(for: label) ?? "—",
                            valueB: productB.specValue(for: label) ?? "—"
                        )
                    }

                    ComparisonRow(
                        title: "Value",
                        valueA: String(format: "%.1f", productA.valueScore.overall),
                        valueB: String(format: "%.1f", productB.valueScore.overall),
                        winner: valueWinner
                    )
                }

                summaryCard

                DemoDataBadge(text: "Celltronics, Abans & Singer prices")
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(productA.id)-\(productB.id)") {
            summary = nil
            summary = await ProductSummarizer.compare(productA, productB)
        }
        .onChange(of: selectedCategory) { _, newCategory in
            (productA, productB) = Self.defaultPair(for: newCategory)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Summary", systemImage: "text.alignleft")
                    .font(BuyWiseTypography.headline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Spacer()
                if let summary {
                    Label(summary.source == .coreML ? "Core ML model" : "From listed specs",
                          systemImage: summary.source == .coreML ? "cpu" : "list.bullet.rectangle")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            if let summary {
                Text(summary.text)
                    .font(BuyWiseTypography.body)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if summary.source == .coreML {
                    Text("Written on your iPhone from the prices and specs above. Check details before buying.")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Summarising…")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bwCard()
    }

    private var selectors: some View {
        HStack(spacing: 12) {
            productPicker(selection: $productA)

            ZStack {
                Circle().fill(BuyWiseColors.brandSoft).frame(width: 30, height: 30)
                Text("vs")
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(BuyWiseColors.brand)
            }

            productPicker(selection: $productB)
        }
    }

    private func productPicker(selection: Binding<Product>) -> some View {
        Menu {
            ForEach(categoryProducts) { product in
                Button("\(product.brand) \(product.name)") {
                    selection.wrappedValue = product
                }
            }
        } label: {
            VStack(spacing: 8) {
                ProductImageView(product: selection.wrappedValue, cornerRadius: BuyWiseTheme.smallRadius, emphasized: true)
                    .frame(height: 76)
                Text(selection.wrappedValue.name)
                    .font(BuyWiseTypography.captionBold)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .lineLimit(1)
                Label("Change", systemImage: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .bwCard(radius: BuyWiseTheme.controlRadius)
        }
    }
}

/// Entry point to Upgrade Analysis from the Compare tab.
struct UpgradeAnalysisEntryCard: View {
    var preselectedNew: Product? = nil

    var body: some View {
        NavigationLink {
            UpgradeAnalysisView(preselectedNew: preselectedNew)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BuyWiseColors.brand))
                VStack(alignment: .leading, spacing: 2) {
                    Text(preselectedNew == nil ? "Upgrade analysis" : "Compare with what you own")
                        .font(BuyWiseTypography.headline)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                    Text(preselectedNew.map { "See what you'd gain upgrading to the \($0.name)." }
                         ?? "See what you'd gain moving from your current product to a new one.")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous).fill(BuyWiseColors.brandSoft))
            .overlay(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous).strokeBorder(BuyWiseColors.brand.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
