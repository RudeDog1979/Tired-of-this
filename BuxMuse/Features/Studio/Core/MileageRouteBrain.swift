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

public struct MileageRouteOption: Identifiable, Equatable, Sendable {
    public var id: Int
    public var distanceMiles: Double
    public var expectedTravelTime: TimeInterval
    public var name: String
    public var coordinates: [CLLocationCoordinate2D]

    public static func == (lhs: MileageRouteOption, rhs: MileageRouteOption) -> Bool {
        lhs.id == rhs.id && lhs.distanceMiles == rhs.distanceMiles && lhs.name == rhs.name
    }
}

public struct MileageAddressResolution: Equatable, Sendable {
    public var places: [MileageResolvedPlace]
    /// Centroid when the user may accept postcode-level accuracy instead of a street address.
    public var postcodeCentre: MileageResolvedPlace?

    public init(places: [MileageResolvedPlace], postcodeCentre: MileageResolvedPlace? = nil) {
        self.places = places
        self.postcodeCentre = postcodeCentre
    }
}

public struct MileageResolvedPlace: Sendable, Identifiable {
    public var label: String
    public var latitude: Double
    public var longitude: Double
    /// House / unit number present on the placemark.
    public var hasPremiseNumber: Bool
    public var postalCode: String?
    public var thoroughfare: String?

    nonisolated public var id: String {
        let coord = String(format: "%.5f|%.5f", latitude, longitude)
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedLabel)|\(coord)"
    }

    nonisolated public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    nonisolated public init(
        label: String,
        latitude: Double,
        longitude: Double,
        hasPremiseNumber: Bool = false,
        postalCode: String? = nil,
        thoroughfare: String? = nil
    ) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.hasPremiseNumber = hasPremiseNumber
        self.postalCode = postalCode
        self.thoroughfare = thoroughfare
    }
}

extension MileageResolvedPlace: Equatable {
    nonisolated public static func == (lhs: MileageResolvedPlace, rhs: MileageResolvedPlace) -> Bool {
        lhs.label == rhs.label
            && lhs.latitude == rhs.latitude
            && lhs.longitude == rhs.longitude
            && lhs.hasPremiseNumber == rhs.hasPremiseNumber
            && lhs.postalCode == rhs.postalCode
            && lhs.thoroughfare == rhs.thoroughfare
    }
}

private struct MileageCompletionSnapshot: Sendable {
    var label: String
    var titleHasHouseNumber: Bool
}

private struct MileageResolvedCandidate: Sendable {
    var place: MileageResolvedPlace
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

    nonisolated private static func displayLabel(title: String, subtitle: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSubtitle.isEmpty { return trimmedTitle }
        if trimmedTitle.isEmpty { return trimmedSubtitle }
        return "\(trimmedTitle), \(trimmedSubtitle)"
    }

    public static func displayLabel(for completion: MKLocalSearchCompletion) -> String {
        displayLabel(title: completion.title, subtitle: completion.subtitle)
    }

    public static func resolve(
        completion: MKLocalSearchCompletion,
        countryCode: String,
        interfaceLocale: Locale
    ) async -> MileageResolvedPlace? {
        await resolveAddress(
            completion: completion,
            countryCode: countryCode,
            interfaceLocale: interfaceLocale
        ).places.first
    }

    public static func resolvePlaces(
        completion: MKLocalSearchCompletion,
        countryCode: String,
        interfaceLocale: Locale
    ) async -> [MileageResolvedPlace] {
        await resolveAddress(
            completion: completion,
            countryCode: countryCode,
            interfaceLocale: interfaceLocale
        ).places
    }

    /// Typed postcode, street, or address — expands to premises when needed.
    public static func resolveAddress(
        query: String,
        countryCode: String,
        interfaceLocale: Locale
    ) async -> MileageAddressResolution {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MileageAddressResolution(places: []) }

        let initial = await resolvePlaces(query: trimmed, countryCode: countryCode, interfaceLocale: interfaceLocale)

        if initial.count == 1, hasLeadingHouseNumber(trimmed) || initial[0].hasPremiseNumber {
            return MileageAddressResolution(places: initial, postcodeCentre: nil)
        }

        if shouldOfferPremisePicker(query: trimmed, places: initial) {
            let expanded = await expandPremisesAddresses(
                postcode: extractPostcode(from: trimmed),
                street: hasLeadingHouseNumber(trimmed) ? nil : trimmed,
                locality: nil,
                countryCode: countryCode,
                interfaceLocale: interfaceLocale,
                coarseCentre: initial.first
            )
            if expanded.places.count >= 2 {
                return expanded
            }
            if let single = expanded.places.first {
                return MileageAddressResolution(places: [single], postcodeCentre: nil)
            }
        }

        if !initial.isEmpty {
            return MileageAddressResolution(places: initial, postcodeCentre: nil)
        }
        return MileageAddressResolution(places: [], postcodeCentre: nil)
    }

    /// Resolves an autocomplete row; expands postcodes and streets to numbered premises / businesses.
    public static func resolveAddress(
        completion: MKLocalSearchCompletion,
        countryCode: String,
        interfaceLocale: Locale,
        siblingCompletions: [MKLocalSearchCompletion] = []
    ) async -> MileageAddressResolution {
        let postcode = extractPostcode(from: completion)
        let street = streetName(from: completion)
        let locality = localityHint(from: completion)
        let wantsPremisePicker = shouldOfferPremisePicker(
            completion: completion,
            places: []
        )

        if wantsPremisePicker, siblingCompletions.count >= 2 {
            let siblings = uniqueCompletions(siblingCompletions)
            let siblingPlaces = await resolveCompletionsToPlaces(
                siblings,
                countryCode: countryCode,
                postcodeFilter: nil
            )
            if siblingPlaces.count >= 2 {
                return MileageAddressResolution(
                    places: siblingPlaces,
                    postcodeCentre: siblingPlaces.first
                )
            }
        }

        if hasLeadingHouseNumber(completion.title) {
            let fallback = displayLabel(for: completion)
            let request = MKLocalSearch.Request(completion: completion)
            request.resultTypes = [.address, .pointOfInterest]
            if let place = await runSearchCandidates(request, fallbackLabel: fallback, limit: 1).first?.place {
                return MileageAddressResolution(places: [place], postcodeCentre: nil)
            }
        }

        if wantsPremisePicker {
            let expanded = await expandPremisesAddresses(
                postcode: postcode,
                street: street,
                locality: locality,
                countryCode: countryCode,
                interfaceLocale: interfaceLocale,
                coarseCentre: nil
            )
            if expanded.places.count >= 2 {
                return expanded
            }
            if let single = expanded.places.first {
                return MileageAddressResolution(places: [single], postcodeCentre: nil)
            }
        }

        let fallback = displayLabel(for: completion)
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]
        if let resolved = await runSearchCandidates(request, fallbackLabel: fallback, limit: 1).first?.place {
            let place = MileageResolvedPlace(
                label: fallback,
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                hasPremiseNumber: resolved.hasPremiseNumber || hasLeadingHouseNumber(completion.title),
                postalCode: resolved.postalCode,
                thoroughfare: resolved.thoroughfare
            )
            return MileageAddressResolution(places: [place], postcodeCentre: nil)
        }
        return MileageAddressResolution(places: [], postcodeCentre: nil)
    }

    public static func resolve(
        query: String,
        countryCode: String,
        interfaceLocale: Locale
    ) async -> MileageResolvedPlace? {
        await resolvePlaces(query: query, countryCode: countryCode, interfaceLocale: interfaceLocale).first
    }

    public static func resolvePlaces(
        query: String,
        countryCode: String,
        interfaceLocale: Locale
    ) async -> [MileageResolvedPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let isExactAddress = hasLeadingHouseNumber(trimmed)
        if isExactAddress {
            if #available(iOS 26, *) {
                if let modern = await modernForwardAddress(trimmed, interfaceLocale: interfaceLocale, countryCode: countryCode) {
                    return [modern]
                }
            }
        }

        let raw = await runSearchCandidates(
            naturalLanguageQuery: trimmed,
            countryCode: countryCode,
            fallbackLabel: trimmed,
            limit: 12
        )
        return raw.map(\.place)
    }

    public static func shouldOfferManualPremiseLookup(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return false }
        return looksLikePostcodeQuery(trimmed) || !hasLeadingHouseNumber(trimmed)
    }

    /// Fresh autocomplete rows for a typed postcode or street (up to `limit`).
    public static func completerSuggestions(
        query: String,
        countryCode: String,
        limit: Int = 25
    ) async -> [MKLocalSearchCompletion] {
        await fetchCompleterSuggestions(query: query, countryCode: countryCode, limit: limit)
    }

    @MainActor
    public static func uniqueCompletions(_ completions: [MKLocalSearchCompletion]) -> [MKLocalSearchCompletion] {
        var seen = Set<String>()
        var unique: [MKLocalSearchCompletion] = []
        for completion in completions {
            let key = "\(completion.title)|\(completion.subtitle)"
            guard seen.insert(key).inserted else { continue }
            unique.append(completion)
        }
        return unique
    }

    @MainActor
    public static func isVagueAddressCompletion(_ completion: MKLocalSearchCompletion) -> Bool {
        !hasLeadingHouseNumber(completion.title)
    }

    public static func formattedLabel(for item: MKMapItem, fallback: String) -> String {
        if #available(iOS 26, *) {
            if let full = item.address?.fullAddress, !full.isEmpty { return full }
            if let short = item.address?.shortAddress, !short.isEmpty { return short }
        }
        if let name = item.name, !name.isEmpty,
           let street = placemarkStreetLine(item.placemark), !street.isEmpty, !name.localizedCaseInsensitiveContains(street) {
            return "\(name), \(street)"
        }
        if let name = item.name, !name.isEmpty { return name }
        if let street = placemarkStreetLine(item.placemark) { return street }
        if let title = item.placemark.title, !title.isEmpty { return title }
        return fallback
    }

    private static func placemarkStreetLine(_ placemark: MKPlacemark) -> String? {
        var parts: [String] = []
        if let number = placemark.subThoroughfare, !number.isEmpty { parts.append(number) }
        if let street = placemark.thoroughfare, !street.isEmpty { parts.append(street) }
        if let locality = placemark.locality, !locality.isEmpty { parts.append(locality) }
        if let postal = placemark.postalCode, !postal.isEmpty { parts.append(postal) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    public static func looksLikePostcodeQuery(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.range(of: #"^\d+\s+\S"#, options: .regularExpression) != nil { return false }
        if trimmed.range(of: #"^[A-Za-z]{1,2}\d[0-9A-Za-z]?\s*\d[0-9A-Za-z]{2}$"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^[A-Za-z]{1,2}\d"#, options: .regularExpression) != nil,
           trimmed.count <= 10 { return true }
        if trimmed.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func shouldOfferPremisePicker(
        completion: MKLocalSearchCompletion,
        places: [MileageResolvedPlace]
    ) -> Bool {
        if hasLeadingHouseNumber(completion.title) { return false }
        if looksLikePostcodeQuery(completion.title) { return true }
        if streetName(from: completion) != nil { return true }
        return shouldOfferPremisePicker(query: completion.title, places: places)
    }

    private static func shouldOfferPremisePicker(
        query: String,
        places: [MileageResolvedPlace]
    ) -> Bool {
        if looksLikePostcodeQuery(query) { return true }
        if hasLeadingHouseNumber(query), places.count == 1, places[0].hasPremiseNumber { return false }
        if places.isEmpty { return true }
        if places.count == 1, !places[0].hasPremiseNumber { return true }
        return !places.contains(where: \.hasPremiseNumber)
    }

    nonisolated private static func hasLeadingHouseNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: #"^\d+[A-Za-z]?\s+\S"#, options: .regularExpression) != nil
    }

    private static func streetName(from completion: MKLocalSearchCompletion) -> String? {
        let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !looksLikePostcodeQuery(title), !hasLeadingHouseNumber(title) else { return nil }
        return title
    }

    private static func localityHint(from completion: MKLocalSearchCompletion) -> String? {
        let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return nil }
        return subtitle.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractPostcode(from completion: MKLocalSearchCompletion) -> String? {
        extractPostcode(from: "\(completion.title) \(completion.subtitle)")
    }

    private static func extractPostcode(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = trimmed.range(
            of: #"[A-Za-z]{1,2}\d[0-9A-Za-z]?\s*\d[0-9A-Za-z]{2}"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            return String(trimmed[match]).uppercased()
        }
        if let match = trimmed.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) {
            return String(trimmed[match])
        }
        return looksLikePostcodeQuery(trimmed) ? trimmed.uppercased() : nil
    }

    private static func expandPremisesAddresses(
        postcode: String?,
        street: String?,
        locality: String?,
        countryCode: String,
        interfaceLocale: Locale,
        coarseCentre: MileageResolvedPlace?
    ) async -> MileageAddressResolution {
        var merged: [MileageResolvedPlace] = []
        var seen = Set<String>()

        func absorb(_ batch: [MileageResolvedPlace]) {
            for place in batch where seen.insert(place.id).inserted {
                merged.append(place)
            }
        }

        var completerQueries: [String] = []
        if let postcode { completerQueries.append(postcode) }
        if let street, let postcode { completerQueries.append("\(street), \(postcode)") }
        else if let street { completerQueries.append(street) }
        if let street, let locality, let postcode {
            completerQueries.append("\(street), \(locality), \(postcode)")
        }

        for query in completerQueries {
            let suggestions = await fetchCompleterSuggestions(
                query: query,
                countryCode: countryCode,
                limit: 25
            )
            let places = await resolveCompletionsToPlaces(
                suggestions,
                countryCode: countryCode,
                postcodeFilter: postcode
            )
            absorb(places)
            if merged.count >= 2 { break }
        }

        if merged.count < 2 {
            var searchQueries: [String] = completerQueries
            if let postcode { searchQueries.append("\(postcode), \(countryCode)") }
            for query in searchQueries {
                let batch = await runSearchCandidates(
                    naturalLanguageQuery: query,
                    countryCode: countryCode,
                    fallbackLabel: query,
                    limit: 25
                )
                absorb(batch.map(\.place))
            }
        }

        if merged.count < 2, let centre = coarseCentre ?? merged.first {
            let regional = MKLocalSearch.Request()
            regional.naturalLanguageQuery = postcode ?? street ?? completerQueries.first ?? ""
            regional.region = MKCoordinateRegion(
                center: centre.coordinate,
                latitudinalMeters: 6_000,
                longitudinalMeters: 6_000
            )
            regional.resultTypes = [.address, .pointOfInterest]
            let regionalBatch = await runSearchCandidates(
                regional,
                fallbackLabel: regional.naturalLanguageQuery ?? "",
                limit: 25
            )
            absorb(regionalBatch.map(\.place))
        }

        let beforeFilter = merged

        if let postcode {
            let target = normalizePostcode(postcode)
            let filtered = merged.filter { place in
                guard let code = place.postalCode else { return true }
                let normalized = normalizePostcode(code)
                return normalized == target || normalized.hasPrefix(target) || target.hasPrefix(normalized)
            }
            if filtered.count >= 2 {
                merged = filtered
            }
        }

        if let street, merged.count >= 2 {
            let streetKey = street.lowercased()
            let filtered = merged.filter { matchesStreet($0, streetKey: streetKey) }
            if filtered.count >= 2 {
                merged = filtered
            }
        }

        if merged.count < 2, beforeFilter.count >= 2 {
            merged = beforeFilter
        }

        merged.sort { lhs, rhs in
            if lhs.hasPremiseNumber != rhs.hasPremiseNumber { return lhs.hasPremiseNumber }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        let centre = coarseCentre ?? merged.first
        let showPicker = merged.count >= 2
        return MileageAddressResolution(
            places: merged,
            postcodeCentre: showPicker ? centre : nil
        )
    }

    @MainActor
    private static func completionSnapshots(
        from completions: [MKLocalSearchCompletion]
    ) -> [MileageCompletionSnapshot] {
        uniqueCompletions(completions).map { completion in
            MileageCompletionSnapshot(
                label: displayLabel(for: completion),
                titleHasHouseNumber: hasLeadingHouseNumber(completion.title)
            )
        }
    }

    private static func resolveCompletionsToPlaces(
        _ completions: [MKLocalSearchCompletion],
        countryCode: String,
        postcodeFilter: String?
    ) async -> [MileageResolvedPlace] {
        let snapshots = await MainActor.run {
            completionSnapshots(from: completions)
        }
        let normalizedFilter = postcodeFilter.map { normalizePostcode($0) }

        return await withTaskGroup(of: MileageResolvedPlace?.self) { group in
            for snapshot in snapshots.prefix(25) {
                let label = snapshot.label
                let titleHasHouseNumber = snapshot.titleHasHouseNumber
                let filter = normalizedFilter
                let country = countryCode
                group.addTask {
                    guard let resolved = await runSearchCandidates(
                        naturalLanguageQuery: label,
                        countryCode: country,
                        fallbackLabel: label,
                        limit: 1
                    ).first?.place else {
                        return nil
                    }
                    if let filter,
                       let code = resolved.postalCode,
                       !code.isEmpty {
                        let normalized = normalizePostcode(code)
                        guard normalized == filter
                            || normalized.hasPrefix(filter)
                            || filter.hasPrefix(normalized) else {
                            return nil
                        }
                    }
                    return MileageResolvedPlace(
                        label: label,
                        latitude: resolved.latitude,
                        longitude: resolved.longitude,
                        hasPremiseNumber: resolved.hasPremiseNumber || titleHasHouseNumber,
                        postalCode: resolved.postalCode,
                        thoroughfare: resolved.thoroughfare
                    )
                }
            }

            var places: [MileageResolvedPlace] = []
            var seen = Set<String>()
            for await place in group {
                guard let place, seen.insert(place.id).inserted else { continue }
                places.append(place)
            }
            places.sort { lhs, rhs in
                if lhs.hasPremiseNumber != rhs.hasPremiseNumber { return lhs.hasPremiseNumber }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return places
        }
    }

    private static func fetchCompleterSuggestions(
        query: String,
        countryCode: String,
        limit: Int
    ) async -> [MKLocalSearchCompletion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        return await CompleterSnapshot(limit: limit).load(query: trimmed, countryCode: countryCode)
    }

    private static func matchesStreet(_ place: MileageResolvedPlace, streetKey: String) -> Bool {
        if place.hasPremiseNumber { return true }
        if let thoroughfare = place.thoroughfare?.lowercased(), thoroughfare.contains(streetKey) { return true }
        if place.label.lowercased().contains(streetKey) { return true }
        let streetToken = streetKey.components(separatedBy: " ").first ?? streetKey
        if streetToken.count >= 3, place.label.lowercased().contains(streetToken) { return true }
        return false
    }

    private static func shouldRelabelAddresses(interfaceLocale: Locale, countryCode: String) -> Bool {
        let interfaceLang = interfaceLocale.language.languageCode?.identifier.lowercased() ?? "en"
        return interfaceLang != primaryLanguage(for: countryCode)
    }

    private static func primaryLanguage(for countryCode: String) -> String {
        switch countryCode.uppercased() {
        case "ES": return "es"
        case "FR": return "fr"
        case "DE": return "de"
        case "IT": return "it"
        case "NL": return "nl"
        case "IE", "GB", "US", "CA", "AU": return "en"
        default: return "en"
        }
    }

    private static func geocodingLocale(interfaceLocale: Locale, countryCode: String) -> Locale {
        let lang = interfaceLocale.language.languageCode?.identifier ?? "en"
        let region = countryCode.uppercased()
        return Locale(identifier: "\(lang)_\(region)")
    }

    private static func relabelPlaces(
        _ places: [MileageResolvedPlace],
        interfaceLocale: Locale,
        countryCode: String
    ) async -> [MileageResolvedPlace] {
        guard shouldRelabelAddresses(interfaceLocale: interfaceLocale, countryCode: countryCode) else {
            return places
        }
        let targetLocale = geocodingLocale(interfaceLocale: interfaceLocale, countryCode: countryCode)
        return await withTaskGroup(of: (Int, MileageResolvedPlace).self) { group in
            for (index, place) in places.enumerated() {
                group.addTask {
                    let relabeled = await relabelPlace(place, locale: targetLocale)
                    return (index, relabeled)
                }
            }
            var output = places
            for await (index, place) in group {
                output[index] = place
            }
            return output
        }
    }

    private static func relabelPlace(_ place: MileageResolvedPlace, locale: Locale) async -> MileageResolvedPlace {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        if let label = await reverseGeocodeLabel(location: location, locale: locale), !label.isEmpty {
            return MileageResolvedPlace(
                label: label,
                latitude: place.latitude,
                longitude: place.longitude,
                hasPremiseNumber: place.hasPremiseNumber,
                postalCode: place.postalCode,
                thoroughfare: place.thoroughfare
            )
        }
        return place
    }

    private static func reverseGeocodeLabel(location: CLLocation, locale: Locale) async -> String? {
        if #available(iOS 26, *) {
            if let modern = await modernReverseLabel(location: location, locale: locale) {
                return modern
            }
        }
        return await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, _ in
                continuation.resume(returning: label(from: placemarks?.first))
            }
        }
    }

    @available(iOS 26, *)
    private static func modernReverseLabel(location: CLLocation, locale: Locale) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            let items = try await request.mapItems
            guard let item = items.first else { return nil }
            let formatted = formattedLabel(for: item, fallback: "")
            if !formatted.isEmpty { return formatted }
            return label(from: item.placemark)
        } catch {
            return nil
        }
    }

    nonisolated private static func normalizePostcode(_ value: String) -> String {
        value.uppercased().replacingOccurrences(of: " ", with: "")
    }

    private static func label(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        if let name = placemark.name, !name.isEmpty,
           let line = placemarkLine(placemark), !name.localizedCaseInsensitiveContains(line) {
            return "\(name), \(line)"
        }
        if let line = placemarkLine(placemark) { return line }
        return placemark.name
    }

    private static func placemarkLine(_ placemark: CLPlacemark) -> String? {
        var parts: [String] = []
        if let number = placemark.subThoroughfare, !number.isEmpty { parts.append(number) }
        if let street = placemark.thoroughfare, !street.isEmpty { parts.append(street) }
        if let locality = placemark.locality, !locality.isEmpty { parts.append(locality) }
        if let postal = placemark.postalCode, !postal.isEmpty { parts.append(postal) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    public static func drivingDistanceMiles(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async -> Double? {
        let routes = await drivingRouteOptions(from: start, to: end)
        return routes.first?.distanceMiles ?? straightLineMiles(from: start, to: end)
    }

    /// Pro — alternate driving routes from MapKit; user picks distance from the selected polyline.
    public static func drivingRouteOptions(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async -> [MileageRouteOption] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            guard !response.routes.isEmpty else { return [] }
            return response.routes.enumerated().map { index, route in
                let miles = (route.distance / metersPerMile * 10).rounded() / 10
                let label = routeLabel(route, index: index)
                return MileageRouteOption(
                    id: index,
                    distanceMiles: miles,
                    expectedTravelTime: route.expectedTravelTime,
                    name: label,
                    coordinates: coordinates(from: route.polyline)
                )
            }
        } catch {
            if let miles = straightLineMiles(from: start, to: end) {
                return [
                    MileageRouteOption(
                        id: 0,
                        distanceMiles: miles,
                        expectedTravelTime: 0,
                        name: "Direct",
                        coordinates: [start, end]
                    )
                ]
            }
            return []
        }
    }

    public static func mapRectFitting(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        routes: [MileageRouteOption]
    ) -> MKMapRect {
        var rect = MKMapRect.null
        let points = [start, end] + routes.flatMap(\.coordinates)
        for coordinate in points {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }
        if rect.isNull {
            return MKMapRect(origin: MKMapPoint(start), size: MKMapSize(width: 1000, height: 1000))
        }
        let padding = max(rect.size.width, rect.size.height) * 0.18
        return rect.insetBy(dx: -padding, dy: -padding)
    }

    private static func routeLabel(_ route: MKRoute, index: Int) -> String {
        let trimmed = route.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "Route \(index + 1)"
    }

    private static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        guard polyline.pointCount > 0 else { return [] }
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: polyline.pointCount
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
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
    private static func modernForwardAddress(
        _ address: String,
        interfaceLocale: Locale,
        countryCode: String
    ) async -> MileageResolvedPlace? {
        guard let request = MKGeocodingRequest(addressString: address) else { return nil }
        do {
            let items = try await request.mapItems
            guard let item = items.first else { return nil }
            let candidate = placeFrom(item, fallbackLabel: address)
            let relabeled = await relabelPlaces(
                [candidate.place],
                interfaceLocale: interfaceLocale,
                countryCode: countryCode
            )
            return relabeled.first
        } catch {
            return nil
        }
    }

    private static func runSearchCandidates(
        naturalLanguageQuery: String,
        countryCode: String,
        fallbackLabel: String,
        limit: Int
    ) async -> [MileageResolvedCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = naturalLanguageQuery
        request.region = searchRegion(for: countryCode)
        request.resultTypes = [.address, .pointOfInterest]
        return await runSearchCandidates(request, fallbackLabel: fallbackLabel, limit: limit)
    }

    private static func runSearchCandidates(
        _ request: MKLocalSearch.Request,
        fallbackLabel: String,
        limit: Int = 12
    ) async -> [MileageResolvedCandidate] {
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            var seen = Set<String>()
            var candidates: [MileageResolvedCandidate] = []
            for item in response.mapItems.prefix(limit) {
                let candidate = placeFrom(item, fallbackLabel: fallbackLabel)
                guard seen.insert(candidate.place.id).inserted else { continue }
                candidates.append(candidate)
            }
            return candidates
        } catch {
            return []
        }
    }

    private static func placeFrom(_ item: MKMapItem, fallbackLabel: String) -> MileageResolvedCandidate {
        let coord = item.placemark.coordinate
        let label = formattedLabel(for: item, fallback: fallbackLabel)
        let premise = !(item.placemark.subThoroughfare ?? "").isEmpty || hasLeadingHouseNumber(label)
        let place = MileageResolvedPlace(
            label: label,
            latitude: coord.latitude,
            longitude: coord.longitude,
            hasPremiseNumber: premise,
            postalCode: item.placemark.postalCode,
            thoroughfare: item.placemark.thoroughfare
        )
        return MileageResolvedCandidate(place: place)
    }

    /// Optional — relabel a single chosen place to the Settings UI language.
    public static func relabelSelectedPlace(
        _ place: MileageResolvedPlace,
        interfaceLocale: Locale,
        countryCode: String
    ) async -> MileageResolvedPlace {
        let relabeled = await relabelPlaces([place], interfaceLocale: interfaceLocale, countryCode: countryCode)
        return relabeled.first ?? place
    }
}

// MARK: - One-shot completer fetch (MainActor)

@MainActor
private final class CompleterSnapshot: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?
    private let limit: Int

    init(limit: Int) {
        self.limit = limit
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func load(query: String, countryCode: String) async -> [MKLocalSearchCompletion] {
        completer.region = MileageRouteBrain.searchRegion(for: countryCode)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: Array(completer.results.prefix(limit)))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: [])
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

    public private(set) var countryCode: String = "GB"
    public private(set) var interfaceLocale: Locale = .autoupdatingCurrent

    public func configure(countryCode: String, interfaceLocale: Locale) {
        self.countryCode = countryCode
        self.interfaceLocale = interfaceLocale
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
