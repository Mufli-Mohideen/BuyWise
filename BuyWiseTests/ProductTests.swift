import Foundation
import Testing
@testable import BuyWise

struct ProductTests {
    private func makePhone(name: String = "Galaxy A36", listings: [RetailerListing] = []) -> Product {
        Product(
            id: UUID(), name: name, brand: "Samsung", category: .smartphones,
            listings: listings, specifications: [Specification("Storage", "128GB")],
            priceHistory: [], keySpec: ""
        )
    }

    @Test func fullNameAddsBrand() {
        #expect(makePhone(name: "Galaxy A36").fullName == "Samsung Galaxy A36")
    }

    @Test func fullNameDoesNotRepeatBrand() {
        #expect(makePhone(name: "Samsung Galaxy A36").fullName == "Samsung Galaxy A36")
    }

    @Test func startingPriceIsLowestListingAndSavingsIsTheGap() {
        let phone = makePhone(listings: [
            RetailerListing(retailer: .abans, price: 120_000),
            RetailerListing(retailer: .singer, price: 100_000)
        ])
        #expect(phone.startingPrice == 100_000)
        #expect(phone.lowestListing.retailer == .singer)
        #expect(phone.savings == 20_000)
        #expect(phone.isSold)
    }

    @Test func productWithoutListingsIsNotSold() {
        let phone = makePhone(listings: [])
        #expect(!phone.isSold)
        #expect(phone.startingPrice == 0)
    }

    @Test func findsSpecValueByLabel() {
        #expect(makePhone().specValue(for: "Storage") == "128GB")
        #expect(makePhone().specValue(for: "Camera") == nil)
    }

    @Test func readsCategoryAndRetailerFromDatabaseValues() {
        #expect(ProductCategory(databaseValue: "laptops") == .laptops)
        #expect(ProductCategory(databaseValue: "tablets") == nil)
        #expect(Retailer(databaseID: "abans") == .abans)
        #expect(Retailer(databaseID: "amazon") == nil)
    }
}
