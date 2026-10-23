import Testing
@testable import BuyWise

struct SpecMathTests {
    @Test func readsFirstNumberFromText() {
        #expect(SpecMath.number("Up to 27 hours video") == 27)
        #expect(SpecMath.number("6.1\" display") == 6.1)
    }

    @Test func returnsNilWhenTextHasNoNumber() {
        #expect(SpecMath.number("Yes") == nil)
        #expect(SpecMath.number(nil) == nil)
    }

    @Test func convertsTerabytesToGigabytes() {
        #expect(SpecMath.gigabytes("256GB") == 256)
        #expect(SpecMath.gigabytes("1TB") == 1024)
    }

    @Test func newerChipGetsHigherTier() {
        #expect(SpecMath.chipTier("Apple A18") > SpecMath.chipTier("Apple A15 Bionic"))
        #expect(SpecMath.chipTier("Apple M3") > SpecMath.chipTier("Apple M1"))
        #expect(SpecMath.chipTier("Snapdragon 8 Elite") > SpecMath.chipTier("Snapdragon 685"))
    }

    @Test func unknownChipGetsMiddleTier() {
        #expect(SpecMath.chipTier("Some Unknown Chip") == 6)
    }
}
