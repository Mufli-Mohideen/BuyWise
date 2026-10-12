import SwiftUI

struct ValueScoreGauge: View {
    let score: Double
    var size: CGFloat = 108
    var lineWidth: CGFloat = 10

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat { CGFloat(score / 10) }
    private var color: Color { BuyWiseTheme.valueScoreColor(score) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(BuyWiseColors.surfaceSecondary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(BuyWiseColors.textPrimary)
                    .contentTransition(.numericText())
                Text("/ 10")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { animatedProgress = progress }
        }
        .onChange(of: score) { _, _ in
            withAnimation(.easeOut(duration: 0.6)) { animatedProgress = progress }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Value score \(String(format: "%.1f", score)) out of 10")
    }
}

struct ValueMetricRow: View {
    let title: String
    let weight: Double
    let score: Double
    let detail: String

    private var contribution: Double { score * weight }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(BuyWiseTypography.subheadline)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Text("× \(Int(weight * 100))%")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Spacer()
                Text(String(format: "%.1f", score))
                    .font(BuyWiseTypography.priceSmall)
                    .foregroundStyle(BuyWiseTheme.valueScoreColor(score))
                    .contentTransition(.numericText())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(BuyWiseColors.surfaceSecondary)
                    Capsule()
                        .fill(BuyWiseTheme.valueScoreColor(score))
                        .frame(width: geometry.size.width * CGFloat(score / 10))
                }
            }
            .frame(height: 6)
            HStack {
                Text(detail)
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
                Spacer()
                Text("+\(String(format: "%.1f", contribution)) pts")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }
        }
    }
}

struct ValueScoreCard: View {
    let valueScore: ValueScore
    @EnvironmentObject private var appState: AppState
    @State private var showFormula = false
    @State private var showPriorities = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 18) {
                ValueScoreGauge(score: valueScore.overall)

                VStack(alignment: .leading, spacing: 6) {
                    Text("BuyWise Value Score")
                        .font(BuyWiseTypography.captionBold)
                        .foregroundStyle(BuyWiseColors.textSecondary)
                    Text(BuyWiseTheme.valueScoreLabel(valueScore.overall))
                        .font(BuyWiseTypography.title)
                        .foregroundStyle(BuyWiseTheme.valueScoreColor(valueScore.overall))
                    Button { showPriorities = true } label: {
                        Label(appState.shoppingPriority == .balanced ? "Personalise" : "Priority: \(appState.shoppingPriority.rawValue)",
                              systemImage: appState.shoppingPriority.symbolName)
                            .font(BuyWiseTypography.captionBold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(BuyWiseColors.brandSoft))
                            .foregroundStyle(BuyWiseColors.brand)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 16) {
                ValueMetricRow(title: "Specs for the price", weight: ValueScoreCalculator.weightD, score: valueScore.specificationValue, detail: valueScore.specDetail)
                ValueMetricRow(title: "Price position", weight: ValueScoreCalculator.weightP, score: valueScore.pricePosition, detail: valueScore.priceDetail)
                ValueMetricRow(title: "Price history", weight: ValueScoreCalculator.weightH, score: valueScore.priceStability, detail: valueScore.historyDetail)
            }

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showFormula.toggle() }
                } label: {
                    HStack {
                        Label("How this score is calculated", systemImage: "function")
                            .font(BuyWiseTypography.subheadline)
                            .foregroundStyle(BuyWiseColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BuyWiseColors.textSecondary)
                            .rotationEffect(.degrees(showFormula ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)

                if showFormula {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Value = 10 × (0.5·Specs + 0.3·Price + 0.2·History)")
                            .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            .foregroundStyle(BuyWiseColors.brand)
                        Text(String(format: "= 10 × (0.5·%.2f + 0.3·%.2f + 0.2·%.2f) = %.1f",
                                    valueScore.specificationValue / 10, valueScore.pricePosition / 10,
                                    valueScore.priceStability / 10, valueScore.overall))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(BuyWiseColors.textSecondary)
                        formulaLine("Specs", "Key specifications divided by price, compared with other products in this category.")
                        formulaLine("Price", "Current lowest price against the category average (average = 0.5, cheaper scores higher).")
                        formulaLine("History", "How much the price has moved over the last 90 days.")
                    }
                    .padding(14)
                    .bwSecondarySurface()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(18)
        .bwCard()
        .animation(.easeInOut(duration: 0.3), value: valueScore.overall)
        .sheet(isPresented: $showPriorities) {
            NavigationStack { ShoppingPrioritiesView() }
                .presentationDetents([.medium, .large])
        }
    }

    private func formulaLine(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textPrimary)
                .frame(width: 52, alignment: .leading)
            Text(text)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
