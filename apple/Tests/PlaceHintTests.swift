import Testing

/// D15: what a statement line says about where a purchase happened.
@MainActor
struct PlaceHintTests {
    @Test func appleCardAddress() throws {
        let h = try #require(PlaceHint.from(description: "BLUE PAN PIZZA 3930 W 38TH AVE DENVER 80212 CO USA", merchant: "Blue Pan Pizza"))
        #expect(h.rest == "3930 W 38TH AVE DENVER 80212 CO")
        #expect(h.zip == "80212")
        #expect(h.state == "CO")
        #expect(h.isAddress)
        #expect(h.query(for: "Blue Pan Pizza") == "Blue Pan Pizza 3930 W 38Th Ave Denver 80212 Co")
    }

    @Test func financeKitCity() throws {
        let h = try #require(PlaceHint.from(description: "crumbl greenwood villa", merchant: "Crumbl"))
        #expect(h.rest == "GREENWOOD VILLA")
        #expect(h.zip == nil)
        #expect(!h.isAddress)
    }

    @Test func noPlace() {
        // Words that aren't a place ("INTEREST CHARGE") still parse; the Maps
        // search keeps only results named like the Setting, so they find nothing.
        #expect(PlaceHint.from(description: "INTEREST CHARGE", merchant: "Interest")?.isAddress == false)
        #expect(PlaceHint.from(description: "SQ *JOES COFFEE 1234", merchant: "") == nil)
        #expect(PlaceHint.from(description: "Denver Zoo", merchant: "Denver Zoo") == nil)
    }

    @Test func namesMatchIncludingChains() {
        #expect(PlaceHint.nameMatches("Denver Zoo", "Denver Zoo"))
        #expect(PlaceHint.nameMatches("Crumbl", "Crumbl Cookies"))
        #expect(PlaceHint.nameMatches("Apple Store", "Apple Park Meadows"), "Apple names its stores Apple <mall>")
        #expect(!PlaceHint.nameMatches("Apple Store", "Applebee's Grill + Bar"))
        #expect(!PlaceHint.nameMatches("Apple Store", "Best Buy"))
        #expect(!PlaceHint.nameMatches("Big Bear Lake", "Big Lots"), "a short lead word is not a brand")
        #expect(!PlaceHint.nameMatches("Golden Corral", "Golden Gate Park"), "a common lead word is not a brand")
    }

    @Test func statementNamesAStore() {
        #expect(PlaceHint.namesStore(description: "Apple Store", merchant: "Apple Store"), "FinanceKit's bare store name")
        #expect(PlaceHint.namesStore(description: "crumbl greenwood villa", merchant: "Crumbl"))
        #expect(!PlaceHint.namesStore(description: "MONTHLY INSTALLMENTS (3 OF 12)", merchant: "Apple"), "an installment is not a place")
        #expect(PlaceHint.namesStore(description: "INTEREST CHARGE", merchant: "Interest"), "Interest names itself; the Maps name filter then finds nothing")
    }
}

