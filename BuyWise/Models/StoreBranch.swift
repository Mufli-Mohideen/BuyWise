import Foundation
import CoreLocation

struct StoreBranch: Identifiable, Hashable {
    let id: String
    let retailer: Retailer
    let branchName: String
    let storeType: String?
    let address: String
    let coordinate: CLLocationCoordinate2D
    /// Minutes after midnight, parsed from the retailer's listing; nil when the retailer doesn't publish hours.
    let opensAt: Int?
    let closesAt: Int?

    init(id: String, retailer: Retailer, branchName: String, storeType: String? = nil, address: String,
         coordinate: CLLocationCoordinate2D, openingHours: String?) {
        self.id = id
        self.retailer = retailer
        self.branchName = branchName
        self.storeType = storeType
        self.address = address
        self.coordinate = coordinate
        let hours = Self.parseHours(openingHours)
        self.opensAt = hours?.opens
        self.closesAt = hours?.closes
    }

    var hasHours: Bool { opensAt != nil && closesAt != nil }

    /// "Open", "Closed", or "Hours" when the retailer doesn't publish opening times.
    var statusText: String { hasHours ? (isOpenNow ? "Open" : "Closed") : "Hours" }

    var isOpenNow: Bool {
        guard let opensAt, let closesAt else { return false }
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return minutes >= opensAt && minutes < closesAt
    }

    var hoursText: String {
        guard let opensAt, let closesAt else { return "Opening hours not listed" }
        return isOpenNow ? "Open until \(Self.format(closesAt))" : "Closed · Opens \(Self.format(opensAt))"
    }

    var shortHoursText: String {
        guard let opensAt, let closesAt else { return "Hours not listed" }
        return isOpenNow ? "Until \(Self.format(closesAt))" : "Opens \(Self.format(opensAt))"
    }

    private static func format(_ minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        let suffix = hour >= 12 ? "PM" : "AM"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return minute == 0 ? "\(twelve) \(suffix)" : String(format: "%d:%02d %@", twelve, minute, suffix)
    }

    /// "9:30AM to 5:00PM" or "9.30AM – 7.00 PM, Mon – Sat" → minutes after midnight.
    static func parseHours(_ text: String?) -> (opens: Int, closes: Int)? {
        guard let text,
              let match = text.firstMatch(of: /(?i)(\d{1,2})(?:[:.](\d{2}))?\s*([AP])\.?M\.?\s*(?:to|-|–)\s*(\d{1,2})(?:[:.](\d{2}))?\s*([AP])\.?M/),
              let openHour = Int(match.1), let closeHour = Int(match.4) else { return nil }

        func minutes(_ hour: Int, _ minute: Substring?, _ meridiem: Substring) -> Int {
            let hour24 = hour % 12 + (meridiem.uppercased() == "P" ? 12 : 0)
            return hour24 * 60 + (minute.flatMap { Int($0) } ?? 0)
        }
        let opens = minutes(openHour, match.2, match.3)
        let closes = minutes(closeHour, match.5, match.6)
        return closes > opens ? (opens, closes) : nil
    }

    static func == (lhs: StoreBranch, rhs: StoreBranch) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
