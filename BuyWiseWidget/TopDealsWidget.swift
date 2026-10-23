import SwiftUI
import WidgetKit

struct TopDealsEntry: TimelineEntry {
    let date: Date
    let deals: [ProductSnapshot]
    var loadFailed = false
}

struct TopDealsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopDealsEntry {
        TopDealsEntry(date: .now, deals: ProductSnapshot.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (TopDealsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await entry(for: context.family)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopDealsEntry>) -> Void) {
        Task {
            let entry = await entry(for: context.family)
            // Prices rarely change, so refresh every 2 hours, or sooner if loading failed.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: entry.loadFailed ? 15 : 120, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func entry(for family: WidgetFamily) async -> TopDealsEntry {
        let limit = switch family {
        case .systemSmall: 1
        case .systemMedium: 3
        default: 6
        }
        do {
            return TopDealsEntry(date: .now, deals: try await WidgetCatalog.deals(limit: limit))
        } catch {
            return TopDealsEntry(date: .now, deals: [], loadFailed: true)
        }
    }
}

struct TopDealsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TopDeals", provider: TopDealsProvider()) { entry in
            TopDealsView(entry: entry)
        }
        .configurationDisplayName("Top Deals")
        .description("The biggest discounts at Celltronics, Abans and Singer.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TopDealsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TopDealsEntry

    var body: some View {
        Group {
            if entry.deals.isEmpty {
                WidgetMessage(
                    symbol: entry.loadFailed ? "wifi.exclamationmark" : "tag",
                    text: entry.loadFailed ? "Couldn't load deals right now." : "No deals right now."
                )
            } else if family == .systemSmall, let deal = entry.deals.first {
                SmallDealView(deal: deal)
            } else {
                dealList
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall && !entry.deals.isEmpty {
                WidgetStyle.brandGradient
            } else {
                Color(.systemBackground)
            }
        }
    }

    private var dealList: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            HStack {
                Label("Top Deals", systemImage: "tag.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetStyle.brand)
                    .widgetAccentable()
                Spacer()
                Text("BuyWise")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(entry.deals) { deal in
                Link(destination: deal.deepLink) {
                    DealRow(deal: deal, imageSize: family == .systemLarge ? 40 : 30)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct SmallDealView: View {
    let deal: ProductSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                ProductThumbnail(image: deal.image, size: 46)
                Spacer()
                if let discount = deal.discount {
                    Text("-\(WidgetStyle.percent(discount))")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 0)
            Text(deal.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text(WidgetStyle.lkr(deal.price))
                .font(.subheadline.weight(.bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("at \(deal.retailer)")
                .font(.caption2)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .widgetURL(deal.deepLink)
    }
}

private struct DealRow: View {
    let deal: ProductSnapshot
    let imageSize: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            ProductThumbnail(image: deal.image, size: imageSize)
                .overlay(RoundedRectangle(cornerRadius: imageSize * 0.22, style: .continuous).stroke(.quaternary))
            VStack(alignment: .leading, spacing: 1) {
                Text(deal.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(deal.retailer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(WidgetStyle.lkr(deal.price))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let discount = deal.discount {
                    DiscountBadge(discount: discount)
                }
            }
        }
    }
}

extension ProductSnapshot {
    /// Used for the widget gallery and loading placeholders.
    static let samples: [ProductSnapshot] = [
        ProductSnapshot(id: UUID(), name: "Apple iPhone 16 Pro Max 1TB", price: 529_900, regularPrice: 749_900, retailer: "Celltronics", storeCount: 3),
        ProductSnapshot(id: UUID(), name: "Samsung Galaxy S25 256GB", price: 289_999, regularPrice: 339_999, retailer: "Abans", storeCount: 2),
        ProductSnapshot(id: UUID(), name: "Sony WH-1000XM5", price: 104_990, regularPrice: 119_990, retailer: "Singer", storeCount: 2),
        ProductSnapshot(id: UUID(), name: "Apple MacBook Air M3", price: 399_900, regularPrice: 429_900, retailer: "Celltronics", storeCount: 3),
        ProductSnapshot(id: UUID(), name: "Redmi 15 128GB", price: 47_999, regularPrice: 52_999, retailer: "Singer", storeCount: 3),
        ProductSnapshot(id: UUID(), name: "JBL Tune 770NC", price: 32_990, regularPrice: 35_990, retailer: "Abans", storeCount: 2),
    ]
}
