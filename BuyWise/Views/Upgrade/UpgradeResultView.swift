import SwiftUI

/// Step 2: the evidence. Presents numbers and changes only, with no verdict.
struct UpgradeResultView: View {
    let analysis: UpgradeAnalysis
    @State private var showUnchangedFeatures = false
    @State private var summary: ProductSummarizer.Summary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                productsHeader
                costCard
                if !analysis.metrics.isEmpty { keyChanges }
                specificationComparison
                featureChanges
                priceHistory
                if !analysis.costPerImprovement.isEmpty { costPerImprovement }
                summaryCard
            }
            .padding(20)
        }
        .bwScreenBackground()
        .task(id: "\(analysis.current.id)-\(analysis.new.id)") {
            summary = await ProductSummarizer.upgrade(analysis)
        }
        .navigationTitle("Upgrade analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 1–2. Current → New

    private var productsHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            productTile(analysis.current, role: "You own")
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(BuyWiseColors.brand))
                .padding(.top, 52)
            productTile(analysis.new, role: "Considering")
        }
    }

    private func productTile(_ product: Product, role: String) -> some View {
        VStack(spacing: 8) {
            ProductImageView(product: product, cornerRadius: BuyWiseTheme.smallRadius)
                .frame(height: 110)
            Text(role.uppercased())
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.brand)
            Text(product.name)
                .font(BuyWiseTypography.headline)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(product.brand)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .bwCard()
    }

    // MARK: 3. Upgrade cost

    private var costCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade cost")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    Text(PriceFormatter.lkr(analysis.upgradeCost))
                        .font(BuyWiseTypography.priceXL)
                        .foregroundStyle(BuyWiseColors.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lowest price at")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    RetailerLogoView(retailer: analysis.costRetailer, height: 16)
                }
            }

            VStack(spacing: 8) {
                ForEach(analysis.new.listings) { listing in
                    HStack {
                        RetailerLogoView(retailer: listing.retailer, height: 13)
                        Spacer()
                        Text(PriceFormatter.lkr(listing.price))
                            .font(BuyWiseTypography.priceSmall)
                            .foregroundStyle(listing.retailer == analysis.costRetailer ? BuyWiseColors.textPrimary : BuyWiseColors.textSecondary)
                    }
                }
            }
            .padding(12)
            .bwSecondarySurface()

            Text("Based on the full price of the new product. Trade-in or resale value of your current product isn't included.")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
        .padding(16)
        .bwCard()
    }

    // MARK: 4. Key changes

    private var keyChanges: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Key changes", subtitle: "\(analysis.current.name) → \(analysis.new.name)")
            VStack(spacing: 0) {
                ForEach(Array(analysis.metrics.enumerated()), id: \.element.id) { index, metric in
                    MetricChangeRow(metric: metric)
                    if index < analysis.metrics.count - 1 {
                        Divider().overlay(BuyWiseColors.border)
                    }
                }
            }
            .padding(.horizontal, 14)
            .bwCard()
            if analysis.new.category != .headphones {
                Text("Performance and camera scores are sample benchmark figures for comparison only.")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
        }
    }

    // MARK: 5. Specification comparison

    private var specificationComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Specification comparison")
            VStack(spacing: 8) {
                HStack {
                    Text(analysis.current.name).frame(maxWidth: .infinity, alignment: .leading)
                    Text(analysis.new.name).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .padding(.horizontal, 14)

                ForEach(analysis.specRows) { row in
                    VStack(spacing: 8) {
                        HStack {
                            Text(row.label.uppercased())
                                .font(BuyWiseTypography.captionBold)
                                .foregroundStyle(BuyWiseColors.textSecondary)
                            Spacer()
                            StatusTag(status: row.status, isDifferent: row.isDifferent)
                        }
                        HStack(alignment: .top) {
                            Text(row.current)
                                .foregroundStyle(BuyWiseColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(BuyWiseColors.textSecondary.opacity(0.6))
                            Text(row.new)
                                .foregroundStyle(BuyWiseColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(BuyWiseTypography.subheadline)
                        .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .bwSecondarySurface()
                }
            }
        }
    }

    // MARK: 6. Feature changes

    private var featureChanges: some View {
        let features = analysis.features
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Feature changes")
            VStack(alignment: .leading, spacing: 14) {
                if !features.gained.isEmpty {
                    featureGroup(title: "Gained", symbol: "plus.circle.fill", tint: BuyWiseColors.success, items: features.gained)
                }
                if !features.changed.isEmpty {
                    featureGroup(title: "Updated", symbol: "arrow.up.circle.fill", tint: BuyWiseColors.brand,
                                 items: features.changed.map { "\($0.name): \($0.from) → \($0.to)" })
                }
                if !features.lost.isEmpty {
                    featureGroup(title: "Lost", symbol: "minus.circle.fill", tint: BuyWiseColors.error, items: features.lost)
                }
                if features.gained.isEmpty && features.changed.isEmpty && features.lost.isEmpty {
                    Text("No feature differences recorded between these models.")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
                if !features.unchanged.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showUnchangedFeatures.toggle() }
                    } label: {
                        HStack {
                            Label("\(features.unchanged.count) unchanged", systemImage: "equal.circle.fill")
                                .font(BuyWiseTypography.subheadline)
                                .foregroundStyle(BuyWiseColors.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(BuyWiseColors.textSecondary)
                                .rotationEffect(.degrees(showUnchangedFeatures ? 180 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    if showUnchangedFeatures {
                        FlowLayout(spacing: 8) {
                            ForEach(features.unchanged, id: \.self) { chip($0, tint: BuyWiseColors.textSecondary) }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(16)
            .bwCard()
        }
    }

    private func featureGroup(title: String, symbol: String, tint: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(BuyWiseTypography.subheadline)
                .foregroundStyle(tint)
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { chip($0, tint: tint) }
            }
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(BuyWiseTypography.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(BuyWiseColors.textPrimary)
    }

    // MARK: 7. Price history

    @ViewBuilder
    private var priceHistory: some View {
        if let price = analysis.price {
            VStack(alignment: .leading, spacing: 12) {
                PriceHistoryChart(fullHistory: analysis.new.priceHistory)
                HStack(spacing: 10) {
                    priceStat("Current", PriceFormatter.lkr(price.current))
                    priceStat("90-day average", PriceFormatter.lkr(price.average))
                }
                Label("The current price is \(price.description).", systemImage: price.percentVsAverage < -2 ? "arrow.down.right" : price.percentVsAverage > 2 ? "arrow.up.right" : "equal")
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .bwSecondarySurface()
            }
        }
    }

    private func priceStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
            Text(value)
                .font(BuyWiseTypography.priceMedium)
                .foregroundStyle(BuyWiseColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .bwCard()
    }

    // MARK: 8. Cost per improvement

    private var costPerImprovement: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cost per 1% improvement", subtitle: "Upgrade cost ÷ improvement")
            VStack(spacing: 0) {
                ForEach(Array(analysis.costPerImprovement.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.metric.title)
                                .font(BuyWiseTypography.subheadline)
                                .foregroundStyle(BuyWiseColors.textPrimary)
                            Text("\(PriceFormatter.lkr(analysis.upgradeCost)) ÷ \(UpgradeAnalysis.percentText(item.metric.improvementPercent))")
                                .font(BuyWiseTypography.caption)
                                .foregroundStyle(BuyWiseColors.textSecondary)
                        }
                        Spacer()
                        Text(PriceFormatter.lkr(item.costPerPercent))
                            .font(BuyWiseTypography.priceSmall)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                    }
                    .padding(.vertical, 12)
                    if index < analysis.costPerImprovement.count - 1 {
                        Divider().overlay(BuyWiseColors.border)
                    }
                }
            }
            .padding(.horizontal, 14)
            .bwCard()
            Label("A numerical comparison only, not a recommendation. Improvements under 5% are left out because the figure isn't meaningful.", systemImage: "info.circle")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
    }

    // MARK: 9. Neutral summary

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
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Summarising…")
                        .font(BuyWiseTypography.caption)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            Text("BuyWise lays out the facts. Whether to upgrade is your call.")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: BuyWiseTheme.cardRadius, style: .continuous).fill(BuyWiseColors.brandSoft))
    }
}

private struct MetricChangeRow: View {
    let metric: UpgradeMetric

    private var tint: Color {
        switch metric.status {
        case .better: return BuyWiseColors.success
        case .worse: return BuyWiseColors.error
        case .unchanged: return BuyWiseColors.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text("\(metric.formatted(metric.currentValue)) → \(metric.formatted(metric.newValue))")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if metric.showsPercent && metric.status != .unchanged {
                    Text(UpgradeAnalysis.signedPercent(metric.changePercent))
                        .font(BuyWiseTypography.priceMedium)
                        .foregroundStyle(tint)
                }
                StatusTag(status: metric.status, isDifferent: true, lowerIsBetter: metric.lowerIsBetter, isVersion: !metric.showsPercent)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusTag: View {
    let status: UpgradeMetric.Status?
    let isDifferent: Bool
    var lowerIsBetter = false
    var isVersion = false

    private var content: (String, Color) {
        switch status {
        case .better?: return (isVersion ? "Newer" : lowerIsBetter ? "Better (lighter)" : "Better", BuyWiseColors.success)
        case .worse?: return (isVersion ? "Older" : lowerIsBetter ? "Worse (heavier)" : "Worse", BuyWiseColors.error)
        case .unchanged?: return ("Unchanged", BuyWiseColors.textSecondary)
        case nil: return isDifferent ? ("Different", BuyWiseColors.brand) : ("Unchanged", BuyWiseColors.textSecondary)
        }
    }

    var body: some View {
        Text(content.0)
            .font(BuyWiseTypography.captionBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(content.1.opacity(0.12)))
            .foregroundStyle(content.1)
    }
}
