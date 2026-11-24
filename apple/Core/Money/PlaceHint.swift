import Foundation

/// D15: what a statement line says about where a purchase happened. Apple Card
/// exports carry the street, city, ZIP and state after the store name
/// ("BLUE PAN PIZZA 3930 W 38TH AVE DENVER 80212 CO USA"); FinanceKit often
/// keeps a city ("crumbl greenwood villa"). The words after the store name
/// become the Apple Maps query; nothing here leaves the phone on its own.
struct PlaceHint: Equatable, Sendable {
    /// The statement's words after the store name, in order ("3930 W 38TH AVE DENVER 80212 CO").
    var rest: String
    var zip: String?
    var state: String?
    /// A house number or ZIP: enough to point at one storefront.
    var isAddress: Bool

    static let states: Set<String> = ["AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","PR"]

    /// nil when the statement names no place beyond the store.
    static func from(description: String, merchant: String) -> PlaceHint? {
        var words = description.uppercased()
            .replacingOccurrences(of: "*", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        if words.last == "USA" || words.last == "US" { words.removeLast() }
        let storeWords = Money.cleanMerchant(merchant.isEmpty ? description : merchant).uppercased()
            .split(separator: " ").map(String.init)
        var i = 0
        while i < words.count, i < storeWords.count, words[i] == storeWords[i] { i += 1 }
        if i == 0 { return nil }  // the statement doesn't start with the store's name
        let rest = Array(words[i...])
        // A lone store number ("SQ *JOES COFFEE 1234") names no place.
        guard !rest.isEmpty, !(rest.count == 1 && rest[0].allSatisfy(\.isNumber)) else { return nil }
        let zip = rest.first { $0.count == 5 && $0.allSatisfy(\.isNumber) }
        let state = rest.last.flatMap { states.contains($0) ? $0 : nil }
            ?? rest.dropLast().last.flatMap { states.contains($0) && zip == rest.last ? $0 : nil }
        let house = rest.first.map(isHouseNumber) ?? false
        return PlaceHint(rest: rest.joined(separator: " "), zip: zip, state: state, isAddress: house || zip != nil)
    }

    /// The Apple Maps query for this Setting.
    func query(for setting: String) -> String { "\(setting) \(rest.capitalized)" }

    private static func isHouseNumber(_ w: String) -> Bool {
        (1...6).contains(w.count) && w.first?.isNumber == true && w.allSatisfy { $0.isNumber || $0 == "-" }
    }

    /// Most of the Setting's words appear in the place's name ("Crumbl" in
    /// "Crumbl Cookies", "Denver Zoo" in "Denver Zoo").
    nonisolated static func nameMatches(_ setting: String, _ name: String) -> Bool {
        let want = words(setting), have = words(name)
        guard !want.isEmpty else { return false }
        if Double(want.filter(have.contains).count) / Double(want.count) >= 0.6 { return true }
        // A chain: Apple Maps names Apple's stores "Apple Park Meadows", so the
        // brand (the Setting's first word) leading the place's name counts.
        let brand = ordered(setting).first, lead = ordered(name).first
        guard let brand, brand == lead, brand.count >= 4, !commonLeads.contains(brand) else { return false }
        return true
    }

    /// Lead words too common to be a brand ("Big Bear" is not "Big Lots").
    nonisolated static let commonLeads: Set<String> = ["best", "city", "park", "great", "little", "first", "golden", "royal", "grand", "north", "south", "east", "west", "united", "american", "national"]

    nonisolated private static func ordered(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 && $0 != "the" }
    }

    nonisolated private static func words(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 && $0 != "the" })
    }

}
