import Foundation

enum PriceHistoryFactory {
    /// Builds a price history from (daysAgo, price) anchors, ordered oldest to newest.
    static func build(_ anchors: [(daysAgo: Int, price: Double)]) -> [PricePoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return anchors
            .sorted { $0.daysAgo > $1.daysAgo }
            .compactMap { anchor in
                guard let date = calendar.date(byAdding: .day, value: -anchor.daysAgo, to: today) else { return nil }
                return PricePoint(date: date, price: anchor.price)
            }
    }
}
