import Testing
@testable import BuyWise

struct ListingMatcherTests {
    let matcher = ListingMatcher()

    @Test func identicalTitlesMatch() {
        let result = matcher.compare("Apple iPhone 16 128GB Black", "Apple iPhone 16 128GB Black")
        #expect(result.isMatch)
        #expect(result.conflictReason == nil)
    }

    @Test func sameProductWithDifferentWordingMatches() {
        let result = matcher.compare("Apple iPhone 16 128GB Black", "iPhone 16 128GB")
        #expect(result.isMatch)
    }

    @Test func differentStorageDoesNotMatch() {
        let result = matcher.compare("Apple iPhone 16 128GB", "Apple iPhone 16 256GB")
        #expect(!result.isMatch)
        #expect(!result.storageMatched)
        #expect(result.conflictReason == "Different storage (256GB vs 128GB)")
    }

    @Test func differentGenerationDoesNotMatch() {
        let result = matcher.compare("Sony WH-1000XM5", "Sony WH-1000XM4")
        #expect(!result.isMatch)
        #expect(result.conflictReason?.hasPrefix("Different model") == true)
    }

    @Test func proAndStandardModelsDoNotMatch() {
        let result = matcher.compare("Apple iPhone 16 Pro 128GB", "Apple iPhone 16 128GB")
        #expect(!result.isMatch)
        #expect(!result.variantMatched)
    }

    @Test func parsesStorageAndScreenSizeFromTitle() {
        let listing = ParsedListing("MacBook Air 13-inch M3 16GB 512GB")
        #expect(listing.storage == 512)
        #expect(listing.screenSize == 13)
    }
}
