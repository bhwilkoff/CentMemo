#if os(iOS)
import CoreLocation
import CoreLocationUI
import MapKit
import SwiftUI

/// D15: where a Setting is. CentMemo guesses from the statement's own words
/// (street, city, ZIP) with an Apple Maps search on this phone, and the person
/// confirms the guess once; every visit there then carries the place. No
/// location permission: this is the store's location, never the person's.
/// The Setting page's place: the confirmed one, or the guesses to confirm.
/// Owned by the page, so the search runs even while nothing is shown yet.
@available(iOS 26.0, *)
@Observable
final class SettingPlaceModel {
    var place: APIClient.SettingPlace?
    var guesses: [MKMapItem] = []
    var index = 0
    private var searchedFor: String?

    var guess: MKMapItem? { place == nil && index < guesses.count ? guesses[index] : nil }
    /// D15b: nothing in the statement or the person's places to search near
    /// (FinanceKit often says only "Apple Store"): offer "Find on the map".
    var canSearchNearby = false
    var findingNearby = false

    func load(setting: String, shownName: String, entries: [LedgerEntry]) async {
        place = (try? await APIClient.shared.loadSettingPlaces())?[setting]
        guard place == nil, searchedFor != setting, entries.contains(where: { $0.amountMinor < 0 }) else { return }
        searchedFor = setting
        let home = APIClient.shared.settingPlaces?.values.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } ?? []
        guesses = await PlaceGuess.search(setting: shownName, entries: entries, near: home)
        index = 0
        canSearchNearby = guesses.isEmpty
    }

    /// The person tapped Apple's one-time location button: search near there.
    func searchNear(_ here: CLLocation, setting: String, shownName: String, entries: [LedgerEntry]) async {
        guesses = await PlaceGuess.search(setting: shownName, entries: entries, near: [], here: here)
        index = 0
        findingNearby = false
        canSearchNearby = guesses.isEmpty
    }

    func confirm(_ item: MKMapItem, setting: String, shownName: String) async throws {
        let p = APIClient.SettingPlace(setting: setting, name: item.name ?? shownName, address: Self.address(item),
                                       lat: item.location.coordinate.latitude, lon: item.location.coordinate.longitude)
        try await APIClient.shared.setPlace(setting, to: p)
        place = p
    }

    func forget(setting: String, shownName: String, entries: [LedgerEntry]) async throws {
        try await APIClient.shared.setPlace(setting, to: nil)
        place = nil; searchedFor = nil
        await load(setting: setting, shownName: shownName, entries: entries)
    }

    static func address(_ item: MKMapItem) -> String? {
        item.address?.shortAddress ?? item.address?.fullAddress
    }
}

/// D15: where a Setting is. CentMemo guesses from the statement's own words
/// (street, city, ZIP) with an Apple Maps search on this phone, and the person
/// confirms the guess once; every visit there then carries the place. No
/// location permission: this is the store's location, never the person's.
@available(iOS 26.0, *)
struct SettingPlaceSection: View {
    let model: SettingPlaceModel
    let setting: String
    let shownName: String
    let entries: [LedgerEntry]
    @Environment(SessionStore.self) private var session

    var body: some View {
        if let place = model.place {
            PlaceMap(name: place.name, address: place.address, lat: place.lat, lon: place.lon)
                .contextMenu {
                    Button("Choose a different place", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await run { try await model.forget(setting: setting, shownName: shownName, entries: entries) } }
                    }
                }
                .accessibilityIdentifier("setting-place")
        } else if let item = model.guess {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Is this the place?").font(TypeRamp.bodyStrong)
                PlaceMap(name: item.name ?? shownName, address: SettingPlaceModel.address(item),
                         lat: item.location.coordinate.latitude, lon: item.location.coordinate.longitude)
                HStack {
                    Button("That's it") {
                        Task { await run { try await model.confirm(item, setting: setting, shownName: shownName) } }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("place-confirm")
                    Button(model.index + 1 < model.guesses.count ? "Another" : "Not here") { model.index += 1 }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("place-next")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("place-guess")
        } else if model.canSearchNearby {
            if model.findingNearby {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Search near where you are now. CentMemo uses it once, for this search.")
                        .font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted)
                    LocationButton(.currentLocation) { Task { await locate() } }
                        .labelStyle(.titleAndIcon).symbolVariant(.fill)
                        .foregroundStyle(Color.brandOnPrimary).tint(Color.brandPrimary)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("place-here")
                }
            } else {
                Button("Find on the map", systemImage: "mappin.and.ellipse") { model.findingNearby = true }
                    .font(TypeRamp.caption)
                    .accessibilityIdentifier("place-find")
            }
        }
    }

    /// One reading from the location Apple's button just allowed; never stored.
    private func locate() async {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let here = update.location {
                    await model.searchNear(here, setting: setting, shownName: shownName, entries: entries)
                    return
                }
            }
        } catch { _ = session.handle(error) }
    }

    private func run(_ work: () async throws -> Void) async {
        do { try await work(); UINotificationFeedbackGenerator().notificationOccurred(.success) }
        catch { _ = session.handle(error) }
    }
}

/// A small map with the place's name and address; a tap opens Apple Maps.
@available(iOS 26.0, *)
struct PlaceMap: View {
    let name: String
    let address: String?
    let lat: Double
    let lon: Double

    private var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }

    var body: some View {
        Button {
            let item = MKMapItem(location: CLLocation(latitude: lat, longitude: lon), address: nil)
            item.name = name
            item.openInMaps()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600)),
                    interactionModes: []) {
                    Marker(name, coordinate: coordinate).tint(Color.brandPrimary)
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(TypeRamp.bodyStrong).foregroundStyle(Color.brandText)
                    if let address { Text(address).font(TypeRamp.caption).foregroundStyle(Color.brandTextMuted) }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(address ?? ""). Opens in Maps.")
    }
}

/// The search behind the guess: the Setting's name plus the statement's place
/// words, and only results whose name matches the Setting's.
@available(iOS 26.0, *)
enum PlaceGuess {
    static func search(setting: String, entries: [LedgerEntry], near home: [CLLocationCoordinate2D], here: CLLocation? = nil) async -> [MKMapItem] {
        let hints = entries.compactMap { PlaceHint.from(description: $0.description, merchant: $0.merchant) }
        let hint = hints.first(where: \.isAddress) ?? hints.first
        // A statement that isn't a place ("MONTHLY INSTALLMENTS") gets no guess,
        // unless the person asked to search near where they are.
        guard hint != nil || here != nil || entries.contains(where: { PlaceHint.namesStore(description: $0.description, merchant: $0.merchant) })
        else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = hint?.query(for: setting) ?? setting
        request.resultTypes = .pointOfInterest
        let center = here?.coordinate ?? centroid(home)
        if hint?.isAddress != true, let center {
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        }
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return [] }
        let matches = items.filter { PlaceHint.nameMatches(setting, $0.name ?? "") }
        #if DEBUG
        print("PlaceGuess: \(request.naturalLanguageQuery ?? "") -> \(items.count) results, \(matches.count) named like \(setting)")
        #endif
        guard let center, hint?.isAddress != true else { return Array(matches.prefix(3)) }
        let here = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return Array(matches.sorted { $0.location.distance(from: here) < $1.location.distance(from: here) }.prefix(3))
    }

    private static func centroid(_ points: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !points.isEmpty else { return nil }
        return .init(latitude: points.map(\.latitude).reduce(0, +) / Double(points.count),
                     longitude: points.map(\.longitude).reduce(0, +) / Double(points.count))
    }
}
#endif
