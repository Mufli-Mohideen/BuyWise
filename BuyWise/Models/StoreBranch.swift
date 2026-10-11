import Foundation
import CoreLocation

struct StoreBranch: Identifiable, Hashable {
    let id: String
    let retailer: Retailer
    let branchName: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let opensAt: Int
    let closesAt: Int

    var isOpenNow: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= opensAt && hour < closesAt
    }

    var hoursText: String {
        isOpenNow ? "Open until \(Self.format(closesAt))" : "Closed · Opens \(Self.format(opensAt))"
    }

    var shortHoursText: String {
        isOpenNow ? "Until \(Self.format(closesAt))" : "Opens \(Self.format(opensAt))"
    }

    private static func format(_ hour: Int) -> String {
        let suffix = hour >= 12 ? "PM" : "AM"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve) \(suffix)"
    }

    static func == (lhs: StoreBranch, rhs: StoreBranch) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
