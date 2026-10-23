import AppIntents
import Charts
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct ProductEntity: AppEntity {
    let id: UUID
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Product"
    static let defaultQuery = ProductQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ProductQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ProductEntity] {
        try await WidgetCatalog.productNames(ids: identifiers).map { ProductEntity(id: $0.id, name: $0.name) }
    }

    func entities(matching string: String) async throws -> [ProductEntity] {
        try await WidgetCatalog.productNames(matching: string).map { ProductEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ProductEntity] {
        try await WidgetCatalog.productNames().map { ProductEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectProductIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Product"
    static let description = IntentDescription("Pick the product to watch. Leave it empty to show today's top deal.")

    @Parameter(title: "Product")
    var product: ProductEntity?
}

// MARK: - Timeline

struct PriceWatchEntry: TimelineEntry {
    let date: Date
    let product: ProductSnapshot?
    var loadFailed = false
}

struct PriceWatchProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PriceWatchEntry {
        PriceWatchEntry(date: .now, product: .sampleWithHistory)
    }

    func snapshot(for configuration: SelectProductIntent, in context: Context) async -> PriceWatchEntry {
        context.isPreview ? placeholder(in: context) : await entry(for: configuration)
    }

    func timeline(for configuration: SelectProductIntent, in context: Context) async -> Timeline<PriceWatchEntry> {
        let entry = await entry(for: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: entry.loadFailed ? 15 : 120, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func entry(for configuration: SelectProductIntent) async -> PriceWatchEntry {
        do {
            var id = configuration.product?.id
            if id == nil { id = try await WidgetCatalog.deals(limit: 1).first?.id }
            guard let id else { return PriceWatchEntry(date: .now, product: nil) }
            return PriceWatchEntry(date: .now, product: try await WidgetCatalog.product(id: id))
        } catch {
            return PriceWatchEntry(date: .now, product: nil, loadFailed: true)
        }
    }
}

struct PriceWatchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PriceWatch", intent: SelectProductIntent.self, provider: PriceWatchProvider()) { entry in
            PriceWatchView(entry: entry)
        }
        .configurationDisplayName("Price Watch")
        .description("The lowest price for a product and how it has moved.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Views

struct PriceWatchView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PriceWatchEntry

    var body: some View {
        content
            .widgetURL(entry.product?.deepLink)
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder
    private var content: some View {
        if let product = entry.product {
            switch family {
            case .accessoryInline:
                Text("\(product.name) · \(WidgetStyle.lkr(product.price))")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text(product.name)
                        .font(.headline)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text(WidgetStyle.lkr(product.price))
                        .font(.body.weight(.semibold))
                    Text("Lowest at \(product.retailer)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .systemMedium:
                HStack(spacing: 14) {
                    PriceSummary(product: product)
                    if product.history.count > 1 {
                        PriceSparkline(product: product)
                    }
                }
            default:
                PriceSummary(product: product)
            }
        } else if family == .accessoryInline || family == .accessoryRectangular {
            Text(entry.loadFailed ? "BuyWise: offline" : "BuyWise")
        } else {
            WidgetMessage(
                symbol: entry.loadFailed ? "wifi.exclamationmark" : "magnifyingglass",
                text: entry.loadFailed ? "Couldn't load prices right now." : "Edit the widget to pick a product."
            )
        }
    }
}

private struct PriceSummary: View {
    let product: ProductSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                ProductThumbnail(image: product.image, size: 38)
                    .overlay(RoundedRectangle(cornerRadius: 38 * 0.22, style: .continuous).stroke(.quaternary))
                Spacer()
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundStyle(WidgetStyle.brand)
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
            Text(product.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text(WidgetStyle.lkr(product.price))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WidgetStyle.brand)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(product.storeCount > 1 ? "Lowest of \(product.storeCount) stores · \(product.retailer)" : "At \(product.retailer)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PriceSparkline: View {
    let product: ProductSnapshot

    private var bounds: ClosedRange<Double> {
        let prices = product.history.map(\.price) + [product.price]
        let low = prices.min()!, high = prices.max()!
        // Pad the range so a flat line doesn't sit on the edge.
        let padding = max((high - low) * 0.15, high * 0.01)
        return (low - padding)...(high + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Price history")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let change = product.historyChange, abs(change) >= 0.005 {
                    Label(WidgetStyle.percent(change), systemImage: change < 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(change < 0 ? WidgetStyle.success : .red)
                }
            }
            Chart(Array(product.history.enumerated()), id: \.offset) { item in
                AreaMark(
                    x: .value("Day", item.element.day),
                    yStart: .value("Low", bounds.lowerBound),
                    yEnd: .value("Price", item.element.price)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(WidgetStyle.brand.opacity(0.15))
                LineMark(x: .value("Day", item.element.day), y: .value("Price", item.element.price))
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(WidgetStyle.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: bounds)
        }
        .frame(maxWidth: .infinity)
    }
}

extension ProductSnapshot {
    static var sampleWithHistory: ProductSnapshot {
        var product = samples[0]
        let prices: [Double] = [749_900, 749_900, 699_900, 699_900, 599_900, 529_900]
        product.history = prices.enumerated().map { index, price in
            PricePoint(day: Calendar.current.date(byAdding: .day, value: (index - prices.count) * 15, to: .now)!, price: price)
        }
        return product
    }
}
