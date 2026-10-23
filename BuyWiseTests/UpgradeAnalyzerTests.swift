import Foundation
import Testing
@testable import BuyWise

struct UpgradeAnalyzerTests {
    private func metric(current: Double, new: Double, lowerIsBetter: Bool = false) -> UpgradeMetric {
        UpgradeMetric(title: "Test", unit: "", currentValue: current, newValue: new,
                      lowerIsBetter: lowerIsBetter, showsPercent: true, specLabel: nil)
    }

    @Test func higherValueIsBetter() {
        let result = metric(current: 100, new: 150)
        #expect(result.changePercent == 50)
        #expect(result.status == .better)
    }

    @Test func lowerValueIsBetterForWeight() {
        let result = metric(current: 2.0, new: 1.5, lowerIsBetter: true)
        #expect(result.improvementPercent == 25)
        #expect(result.status == .better)
    }

    @Test func tinyChangeCountsAsUnchanged() {
        #expect(metric(current: 1000, new: 1002).status == .unchanged)
    }

    @Test func analysisComparesSpecsAndUsesCheapestPrice() {
        let oldPhone = Product(
            id: UUID(), name: "Old Phone", brand: "Test", category: .smartphones,
            listings: [], specifications: [Specification("Memory", "4GB"), Specification("Battery", "4000 mAh")],
            priceHistory: [], keySpec: ""
        )
        let newPhone = Product(
            id: UUID(), name: "New Phone", brand: "Test", category: .smartphones,
            listings: [RetailerListing(retailer: .abans, price: 90_000), RetailerListing(retailer: .singer, price: 80_000)],
            specifications: [Specification("Memory", "8GB"), Specification("Battery", "5000 mAh")],
            priceHistory: [], keySpec: ""
        )

        let analysis = UpgradeAnalyzer.analyze(current: oldPhone, new: newPhone)

        #expect(analysis.upgradeCost == 80_000)
        #expect(analysis.costRetailer == .singer)
        let memory = analysis.metrics.first { $0.title == "Memory" }
        #expect(memory?.changePercent == 100)
        #expect(analysis.summary.hasPrefix("Upgrading from the Test Old Phone to the Test New Phone costs LKR 80,000 at Singer."))
    }
}
