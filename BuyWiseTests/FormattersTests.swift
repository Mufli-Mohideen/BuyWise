import Testing
@testable import BuyWise

struct FormattersTests {
    @Test func formatsPriceInRupeesWithCommas() {
        #expect(PriceFormatter.lkr(249_900) == "LKR 249,900")
        #expect(PriceFormatter.lkr(0) == "LKR 0")
    }

    @Test func formatsPercent() {
        #expect(PriceFormatter.percent(12.345) == "12.3%")
        #expect(PriceFormatter.percent(5, fractionDigits: 0) == "5%")
    }

    @Test func joinsListWithAnd() {
        #expect([String]().joinedAsList() == "")
        #expect(["a"].joinedAsList() == "a")
        #expect(["a", "b"].joinedAsList() == "a and b")
        #expect(["a", "b", "c"].joinedAsList() == "a, b and c")
    }
}
