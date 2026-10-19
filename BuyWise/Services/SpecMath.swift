import Foundation

/// Reading numbers out of spec values and ranking chips. Plain Foundation with no app types, so the
/// summary model's training-data script (ml/summarizer) compiles this exact file.
nonisolated enum SpecMath {
    /// First number in a spec value, e.g. "Up to 27 hours video" → 27.
    static func number(_ text: String?) -> Double? {
        guard let text, let range = text.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[range])
    }

    /// "256GB" → 256, "1TB" → 1024.
    static func gigabytes(_ text: String?) -> Double? {
        guard let value = number(text) else { return nil }
        return text?.range(of: "TB", options: .caseInsensitive) != nil ? value * 1024 : value
    }

    /// Approximate performance tier (0–10) from the chip name. A heuristic for comparing chips within
    /// a category, not a benchmark score.
    static func chipTier(_ chip: String) -> Double {
        let chip = chip.lowercased()
        func generation(after prefix: String) -> Int? {
            guard let range = chip.range(of: prefix + #"\s?(\d+)"#, options: .regularExpression) else { return nil }
            return Int(chip[range].filter(\.isNumber))
        }

        // Apple silicon: A-series phones, M-series Macs.
        if let m = generation(after: #"\bm"#), chip.contains("apple") || chip.hasPrefix("m") {
            return min(10, 7.6 + Double(m - 1) * 0.6 + (chip.contains("pro") || chip.contains("max") ? 0.4 : 0))
        }
        if let a = generation(after: #"\ba"#), a >= 10, a <= 30 {
            return min(10, 7.6 + Double(a - 15) * 0.45 + (chip.contains("pro") ? 0.3 : 0))
        }
        // Qualcomm.
        if chip.contains("snapdragon") {
            if chip.contains("x elite") { return 9 }
            if chip.contains("x plus") { return 8.2 }
            if chip.contains("8 elite") { return 9.6 }
            if chip.contains("8 gen 3") { return 9 }
            if chip.contains("8s gen") || chip.contains("8 gen 2") { return 8.5 }
            if chip.contains("8 gen") { return 8 }
            if chip.contains("7") { return 7.1 }
            if chip.contains("6") { return 5.8 }
            if chip.contains("4") { return 4.8 }
            return 6
        }
        // MediaTek.
        if let dimensity = generation(after: "dimensity") {
            switch dimensity {
            case 9400...: return 9.4
            case 9300..<9400: return 8.8
            case 9000..<9300: return 8.3
            case 8000..<9000: return 7.5
            case 7000..<8000: return 6.5
            default: return 5.6
            }
        }
        if chip.contains("helio") { return chip.contains("g9") ? 4.8 : chip.contains("g8") ? 4.3 : 3.8 }
        // Samsung, Google, Huawei, Unisoc.
        if let exynos = generation(after: "exynos") { return exynos >= 2400 ? 8.8 : exynos >= 1300 ? 6.4 : 5.4 }
        if let tensor = generation(after: #"tensor g"#) { return min(9, 7.2 + Double(tensor - 2) * 0.5) }
        if chip.contains("kirin") { return chip.contains("9") ? 8 : 6 }
        if chip.contains("unisoc") || chip.contains("tiger") { return 3.6 }
        // Intel and AMD laptops.
        if chip.contains("ultra 9") { return 9.4 }
        if chip.contains("ultra 7") { return 8.8 }
        if chip.contains("ultra 5") { return 8 }
        if let tier = generation(after: #"\bi"#), [3, 5, 7, 9].contains(tier) {
            let bases: [Int: Double] = [3: 5.5, 5: 7.0, 7: 8.0, 9: 9.0]
            let base = bases[tier] ?? 6
            let fast = chip.contains("hx") || chip.range(of: #"\d{4,5}h\b"#, options: .regularExpression) != nil
            return min(10, base + (fast ? 0.4 : 0))
        }
        if chip.contains("core 7") { return 7.8 }
        if chip.contains("core 5") { return 7 }
        if chip.contains("core 3") { return 5.8 }
        if chip.contains("ryzen ai") { return 8.8 }
        if chip.contains("ryzen 9") { return 9 }
        if chip.contains("ryzen 7") { return 8.2 }
        if chip.contains("ryzen 5") { return 7.2 }
        if chip.contains("ryzen 3") { return 5.6 }
        if chip.contains("celeron") || chip.contains("pentium") || chip.contains("n100") || chip.contains("n200") { return 3.8 }
        return 6
    }
}
