import Testing
@testable import BuyWise

/// Only the input checks that fail before any network call are tested here.
struct ProductIdentifierTests {
    @Test func emptyTextThrowsNoTextFound() async {
        await #expect(throws: IdentificationError.noTextFound) {
            try await ProductIdentifier.identify(text: "   ", method: .name)
        }
    }

    @Test func emptyBarcodeThrowsNoBarcodeFound() async {
        await #expect(throws: IdentificationError.noBarcodeFound) {
            try await ProductIdentifier.identify(barcode: "  \n")
        }
    }

    @Test func linkFromOtherShopThrowsUnsupportedRetailer() async {
        await #expect(throws: IdentificationError.unsupportedRetailer) {
            try await ProductIdentifier.identify(url: "https://www.amazon.com/some-phone")
        }
    }

    @Test func textThatIsNotALinkThrowsNotFound() async {
        await #expect(throws: IdentificationError.notFound) {
            try await ProductIdentifier.identify(url: "not a link")
        }
    }

    @Test func errorsHaveUserFacingMessages() {
        let error: Error = IdentificationError.unsupportedRetailer
        #expect(error.userFacingMessage == "Only Celltronics, Abans and Singer product links are supported.")
    }
}
