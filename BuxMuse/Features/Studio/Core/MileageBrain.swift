//
//  MileageBrain.swift
//  BuxMuse
//
//  Mileage log calculations and display assembly for Studio.
//

import Foundation
import CoreLocation
import Combine
import MapKit

public struct MileageSummaryDisplay: Equatable, Sendable {
    public var businessDistanceTotal: Double
    public var businessDistanceFormatted: String
    public var deductionAmount: Decimal
    public var deductionFormatted: String
    public var entryCount: Int

    public static let empty = MileageSummaryDisplay(
        businessDistanceTotal: 0,
        businessDistanceFormatted: "0",
        deductionAmount: 0,
        deductionFormatted: "—",
        entryCount: 0
    )
}

public enum MileageBrain {

    public static func businessDistanceTotal(entries: [MileageEntry]) -> Double {
        entries
            .filter { $0.purpose == .business && $0.distance > 0 }
            .reduce(0) { $0 + $1.distance }
    }

    public static func deductionAmount(
        entries: [MileageEntry],
        ratePerUnit: Decimal
    ) -> Decimal {
        let miles = Decimal(businessDistanceTotal(entries: entries))
        return miles * ratePerUnit
    }

    public static func summary(
        entries: [MileageEntry],
        ratePerUnit: Decimal,
        formatAmount: (Decimal) -> String,
        distanceUnitLabel: String = "mi"
    ) -> MileageSummaryDisplay {
        let total = businessDistanceTotal(entries: entries)
        let deduction = deductionAmount(entries: entries, ratePerUnit: ratePerUnit)
        return MileageSummaryDisplay(
            businessDistanceTotal: total,
            businessDistanceFormatted: String(format: "%.1f %@", total, distanceUnitLabel),
            deductionAmount: deduction,
            deductionFormatted: formatAmount(deduction),
            entryCount: entries.count
        )
    }

    public static func sortedEntries(_ entries: [MileageEntry]) -> [MileageEntry] {
        entries.sorted { $0.date > $1.date }
    }

    /// Simple distance estimate when user provides place names only (no geocode) — returns 0.
    public static func estimatedDistanceKm(
        from start: String,
        to end: String
    ) -> Double {
        guard !start.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !end.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        return 0
    }

    public static func formatDistance(_ value: Double, unit: String = "mi") -> String {
        String(format: "%.1f %@", value, unit)
    }

    /// Swapped route for the return leg (same distance and purpose as the outbound trip).
    public static func returnTrip(from outbound: MileageEntry, on date: Date? = nil) -> MileageEntry {
        let trimmedNotes = outbound.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let returnNotes: String
        if trimmedNotes.isEmpty {
            returnNotes = "Same trip back"
        } else if trimmedNotes.localizedCaseInsensitiveContains("return")
            || trimmedNotes.localizedCaseInsensitiveContains("same trip back") {
            returnNotes = trimmedNotes
        } else {
            returnNotes = "Same trip back — \(trimmedNotes)"
        }

        return MileageEntry(
            date: date ?? outbound.date,
            startLocation: outbound.endLocation,
            endLocation: outbound.startLocation,
            distance: outbound.distance,
            purpose: outbound.purpose,
            notes: returnNotes,
            startLatitude: outbound.endLatitude,
            startLongitude: outbound.endLongitude,
            endLatitude: outbound.startLatitude,
            endLongitude: outbound.startLongitude
        )
    }
}

// MARK: - Reverse geocode helpers (nonisolated — safe from delegate / geocoder callbacks)

private enum MileagePlacemarkFormatting {
    static func label(from placemark: CLPlacemark?) -> String? {
        guard let p = placemark else { return nil }
        let parts = [p.name, p.locality, p.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    static func coordinateLabel(_ location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
}

private enum MileageReverseGeocoding {
    static func resolveLabel(for location: CLLocation) async -> String {
        if #available(iOS 26, *) {
            if let modern = await modernLabel(for: location) {
                return modern
            }
        }
        if let legacy = await legacyLabel(for: location) {
            return legacy
        }
        return MileagePlacemarkFormatting.coordinateLabel(location)
    }

    @available(iOS 26, *)
    private static func modernLabel(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            let mapItems = try await request.mapItems
            guard let item = mapItems.first else { return nil }
            if let short = item.address?.shortAddress, !short.isEmpty { return short }
            if let full = item.address?.fullAddress, !full.isEmpty { return full }
            if let name = item.name, !name.isEmpty { return name }
        } catch {
            return nil
        }
        return nil
    }

    private static func legacyLabel(for location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                continuation.resume(returning: MileagePlacemarkFormatting.label(from: placemarks?.first))
            }
        }
    }
}

// MARK: - Location helper (optional, settings-gated)

@MainActor
public final class MileageLocationCapture: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published public private(set) var lastPlacemarkLabel: String?
    @Published public private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private var pendingField: LocationField?
    private var onCapture: ((String) -> Void)?

    private enum LocationField { case start, end }

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func captureCurrentLocation(forStart: Bool, completion: @escaping (String) -> Void) {
        pendingField = forStart ? .start : .end
        onCapture = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            authorizationDenied = true
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            authorizationDenied = true
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            await self?.resolveAddress(for: location)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.authorizationDenied = false
            self?.onCapture = nil
        }
    }

    private func resolveAddress(for location: CLLocation) async {
        let label = await MileageReverseGeocoding.resolveLabel(for: location)
        finishLocationCapture(label: label)
    }

    private func finishLocationCapture(label: String) {
        lastPlacemarkLabel = label
        onCapture?(label)
        onCapture = nil
    }
}
