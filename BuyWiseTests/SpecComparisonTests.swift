import Testing
@testable import BuyWise

struct SpecComparisonTests {
    /// Compares a single spec and returns the result.
    private func compare(_ label: String, _ first: String, _ second: String) -> SpecComparison.Fact {
        SpecComparison.facts(first: [(label, first)], second: [(label, second)])[0]
    }

    @Test func moreStorageWins() {
        let fact = compare("Storage", "256GB", "128GB")
        #expect(fact.better == "first")
        #expect(fact.advantage == "more storage")
    }

    @Test func lighterWeightWins() {
        let fact = compare("Weight", "1.2 kg", "1500 g")
        #expect(fact.better == "first")
        #expect(fact.advantage == "a lighter build")
    }

    @Test func identicalValuesAreTheSame() {
        let fact = compare("Storage", "128GB", "128gb")
        #expect(fact.better == "same")
    }

    @Test func batteryInDifferentUnitsCannotBeRanked() {
        let fact = compare("Battery", "5000 mAh", "20 hours")
        #expect(fact.better == nil)
    }

    @Test func specOnlyOneProductListsIsStillIncluded() {
        let facts = SpecComparison.facts(first: [("Storage", "128GB")], second: [("Camera", "50MP")])
        #expect(facts.map(\.label) == ["Storage", "Camera"])
        #expect(facts[1].first == nil)
    }

    @Test func modelInputDescribesBothProducts() {
        let facts = [compare("Storage", "256GB", "128GB")]
        let input = SpecComparison.modelInput(category: "Smartphones", firstName: "Phone A", secondName: "Phone B", facts: facts)
        #expect(input == "compare smartphones: A: Phone A. B: Phone B. Storage: 256GB | 128GB | A more storage.")
    }
}
