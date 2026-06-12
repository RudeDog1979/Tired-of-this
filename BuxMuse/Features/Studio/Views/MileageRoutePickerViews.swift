//
//  MileageRoutePickerViews.swift
//  BuxMuse
//
//  Pro Studio — MapKit alternate route picker + fuel type chips.
//

import SwiftUI
import MapKit

struct MileageRoutePickerSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let routes: [MileageRouteOption]
    @Binding var selectedRouteID: Int?

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }
    private var locale: Locale { appSettingsManager.interfaceLocale }

    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogDynamicText(key: "Choose route")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()

            BuxCatalogDynamicText(key: "Tap a route on the map or below — distance updates from your choice.")
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)

            Map(position: $mapPosition, interactionModes: [.pan, .zoom]) {
                Marker(
                    BuxCatalogLabel.string("Start", locale: locale),
                    coordinate: start
                )
                Marker(
                    BuxCatalogLabel.string("End", locale: locale),
                    coordinate: end
                )
                ForEach(routes) { route in
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(
                            selectedRouteID == route.id ? accent : Color.gray.opacity(colorScheme == .dark ? 0.55 : 0.4),
                            lineWidth: selectedRouteID == route.id ? 5 : 3
                        )
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: pointsOfInterest))
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear { fitMap() }
            .onChange(of: routes) { _, _ in fitMap() }
            .onChange(of: selectedRouteID) { _, _ in fitMap() }

            VStack(spacing: 8) {
                ForEach(routes) { route in
                    routeRow(route)
                }
            }
        }
    }

    private var pointsOfInterest: PointOfInterestCategories {
        [.gasStation, .evCharger]
    }

    private func fitMap() {
        let rect = MileageRouteBrain.mapRectFitting(start: start, end: end, routes: routes)
        mapPosition = .rect(rect)
    }

    private func routeRow(_ route: MileageRouteOption) -> some View {
        let isSelected = selectedRouteID == route.id
        return Button {
            if selectedRouteID != route.id {
                selectedRouteID = route.id
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? accent : themeManager.labelSecondary(for: colorScheme))

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(for: route))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.leading)
                    Text(routeSummary(route))
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? accent.opacity(colorScheme == .dark ? 0.18 : 0.1) : themeManager.cardFill(for: colorScheme))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.45) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func displayName(for route: MileageRouteOption) -> String {
        if route.name.hasPrefix("Route ") {
            return BuxLocalizedString.format(
                "Route %lld",
                locale: locale,
                route.id + 1
            )
        }
        if route.name == "Direct" {
            return BuxCatalogLabel.string("Direct route", locale: locale)
        }
        return route.name
    }

    private func routeSummary(_ route: MileageRouteOption) -> String {
        let miles = String(format: "%.1f", route.distanceMiles)
        let distance = BuxLocalizedString.format("%@ mi", locale: locale, miles)
        guard route.expectedTravelTime > 0 else { return distance }
        let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
        let duration = BuxLocalizedString.format("%lld min", locale: locale, minutes)
        return "\(distance) · \(duration)"
    }
}

struct MileageFuelTypePickerSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var selection: MileageFuelType?

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogDynamicText(key: "Fuel type")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()

            BuxCatalogDynamicText(key: "Optional — for your records. Allowance still uses your per-mile rate.")
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MileageFuelType.allCases) { fuel in
                        fuelChip(fuel)
                    }
                }
            }
        }
    }

    private func fuelChip(_ fuel: MileageFuelType) -> some View {
        let isSelected = selection == fuel
        return Button {
            selection = isSelected ? nil : fuel
        } label: {
            HStack(spacing: 6) {
                Image(systemName: fuel.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(fuel.catalogLabel(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? accent : themeManager.labelPrimary(for: colorScheme))
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? accent.opacity(colorScheme == .dark ? 0.22 : 0.12) : themeManager.cardFill(for: colorScheme))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.5) : themeManager.themedCardStroke(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
