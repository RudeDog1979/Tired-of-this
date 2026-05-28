//
//  MileageRouteBrain.swift
//  BuxMuse
//
//  MapKit address autocomplete and driving-distance calculation for mileage trips.
//  iOS 26 MapKit geocoding first; iOS 18 MKLocalSearch + MKDirections fallback.
//

import Foundation
import MapKit
import CoreLocation
import Combine

public struct MileageResolvedPlace: Equatable, Sendable {
    public var label: String
    public var latitude: Double
    public var longitude: Double

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public enum MileageRouteBrain {

    private static let metersPerMile = 1609.34

    private static let countryCenters: [String: CLLocationCoordinate2D] = [
        "GB": CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        "US": CLLocationCoordinate2D(latitude: 38.9072, longitude: -77.0369),
        "CA": CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        "AU": CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
        "DE": CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        "FR": CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        "IE": CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603),
        "ES": CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        "IT": CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964),
        "NL": CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041),
    ]

    public static func searchRegion(for countryCode: String) -> MKCoordinateRegion {
        let center = countryCenters[countryCode.uppercased()]
            ?? countryCenters["US"]!
        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: 800_000,
            longitudinalMeters: 800_000
        )
    }

    public static func displayLabel(for completion: MKLocalSearchCompletion) -> String {
        let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if subtitle.isEmpty { return title }
        if title.isEmpty { return subtitle }
        return "\(title), \(subtitle)"
    }

    public static func resolve(completion: MKLocalSearchCompletion) async -> MileageResolvedPlace? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]
        return await runSearch(request, fallbackLabel: displayLabel(for: completion))
    }

    public static func resolve(
        query: String,
        countryCode: String
    ) async -> MileageResolvedPlace? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if #available(iOS 26, *) {
            if let modern = await modernForwardAddress(trimmed) {
                return modern
            }
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = searchRegion(for: countryCode)
        request.resultTypes = [.address, .pointOfInterest]
        return await runSearch(request, fallbackLabel: trimmed)
    }

    public static func drivingDistanceMiles(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async -> Double? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return nil }
            let miles = route.distance / metersPerMile
            return (miles * 10).rounded() / 10
        } catch {
            return straightLineMiles(from: start, to: end)
        }
    }

    private static func straightLineMiles(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double? {
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let meters = startLoc.distance(from: endLoc)
        guard meters > 0 else { return nil }
        let miles = meters / metersPerMile
        return (miles * 10).rounded() / 10
    }

    @available(iOS 26, *)
    private static func modernForwardAddress(_ address: String) async -> MileageResolvedPlace? {
        guard let request = MKGeocodingRequest(addressString: address) else { return nil }
        do {
            let items = try await request.mapItems
            guard let item = items.first else { return nil }
            let coord = item.placemark.coordinate
            let label = item.address?.shortAddress
                ?? item.address?.fullAddress
                ?? item.name
                ?? address
            return MileageResolvedPlace(label: label, latitude: coord.latitude, longitude: coord.longitude)
        } catch {
            return nil
        }
    }

    private static func runSearch(
        _ request: MKLocalSearch.Request,
        fallbackLabel: String
    ) async -> MileageResolvedPlace? {
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let label = item.name
                ?? item.placemark.title
                ?? fallbackLabel
            return MileageResolvedPlace(
                label: label,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Autocomplete (MainActor)

@MainActor
public final class MileageAddressAutocompleteModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published public private(set) var completions: [MKLocalSearchCompletion] = []
    @Published public private(set) var isUpdating = false

    private let completer = MKLocalSearchCompleter()

    public override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    public func configure(countryCode: String) {
        completer.region = MileageRouteBrain.searchRegion(for: countryCode)
    }

    public func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completions = []
            isUpdating = false
            return
        }
        isUpdating = true
        completer.queryFragment = trimmed
    }

    public func clear() {
        completions = []
        isUpdating = false
        completer.queryFragment = ""
    }

    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
        isUpdating = false
    }

    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        isUpdating = false
    }
}
