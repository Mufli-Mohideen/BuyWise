import SwiftUI
import Charts

enum HistoryRange: Int, CaseIterable, Identifiable {
    case thirty = 30
    case sixty = 60
    case ninety = 90

    var id: Int { rawValue }
    var label: String { "\(rawValue)D" }
}

struct PriceHistoryChart: View {
    let fullHistory: [PricePoint]
    @State private var range: HistoryRange = .ninety

    private var filtered: [PricePoint] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -range.rawValue, to: .now) else {
            return fullHistory
        }
        return fullHistory.filter { $0.date >= cutoff }
    }

    /// Tight y-range around the data so small price moves are visible.
    private var yDomain: ClosedRange<Double> {
        let padding = max((highest - lowest) * 0.35, highest * 0.02)
        return (lowest - padding)...(highest + padding)
    }

    private var lowest: Double { filtered.map(\.price).min() ?? 0 }
    private var highest: Double { filtered.map(\.price).max() ?? 0 }
    private var current: Double { fullHistory.last?.price ?? 0 }
    private var percentBelowHigh: Double {
        guard highest > 0 else { return 0 }
        return (highest - current) / highest * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("Price History")
                    .font(BuyWiseTypography.title)
                    .foregroundStyle(BuyWiseColors.textPrimary)
                Spacer()
                rangeSelector
            }

            Chart(filtered) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(BuyWiseColors.brand)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", yDomain.lowerBound),
                    yEnd: .value("Price", point.price)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [BuyWiseColors.brand.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(BuyWiseColors.border)
                    AxisValueLabel().foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(range.rawValue / 3, 1))) { _ in
                    AxisGridLine().foregroundStyle(BuyWiseColors.border)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(BuyWiseColors.textSecondary)
                }
            }
            .frame(height: 170)

            HStack {
                statColumn(title: "Lowest", value: lowest)
                Divider().frame(height: 30).overlay(BuyWiseColors.border)
                statColumn(title: "Highest", value: highest)
                Divider().frame(height: 30).overlay(BuyWiseColors.border)
                statColumn(title: "Current", value: current, highlighted: true)
            }

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(BuyWiseColors.brand)
                Text("Current price is \(PriceFormatter.percent(percentBelowHigh)) below the \(range.rawValue)-day high.")
                    .font(BuyWiseTypography.caption)
                    .foregroundStyle(BuyWiseColors.textSecondary)
            }

            Text("Latest price is from Celltronics and Abans; earlier history is simulated for this demo.")
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary.opacity(0.8))
        }
        .padding(18)
        .bwCard()
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(HistoryRange.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { range = option }
                } label: {
                    Text(option.label)
                        .font(BuyWiseTypography.captionBold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(range == option ? BuyWiseColors.brand : Color.clear)
                        )
                        .foregroundStyle(range == option ? .white : BuyWiseColors.textSecondary)
                }
            }
        }
        .padding(3)
        .background(Capsule().fill(BuyWiseColors.surfaceSecondary))
    }

    private func statColumn(title: String, value: Double, highlighted: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(BuyWiseTypography.caption)
                .foregroundStyle(BuyWiseColors.textSecondary)
            Text(PriceFormatter.lkr(value))
                .font(BuyWiseTypography.priceSmall)
                .foregroundStyle(highlighted ? BuyWiseColors.brand : BuyWiseColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
