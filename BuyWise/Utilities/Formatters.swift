import Foundation

enum PriceFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func lkr(_ value: Double) -> String {
        let number = numberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "LKR \(number)"
    }

    static func percent(_ value: Double, fractionDigits: Int = 1) -> String {
        String(format: "%.\(fractionDigits)f%%", value)
    }

    static func compactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

extension Array where Element == String {
    /// "a", "a and b", "a, b and c". Unlike `ListFormatter`, never adds a comma before "and".
    func joinedAsList() -> String {
        switch count {
        case 0: return ""
        case 1: return self[0]
        default: return dropLast().joined(separator: ", ") + " and " + last!
        }
    }
}
