//
//  StudioMileageViews.swift
//  BuxMuse
//
//  Business mileage log and entry sheet for Studio deductions.
//

import SwiftUI
import MapKit

// MARK: - Sheet routing (stable identity per open — avoids empty edit form after reuse)

enum MileageSheetMode: Identifiable {
    case add(openToken: UUID)
    case edit(UUID)

    var id: String {
        switch self {
        case .add(let token): return "add-\(token.uuidString)"
        case .edit(let entryId): return entryId.uuidString
        }
    }

    var editingEntryId: UUID? {
        if case .edit(let entryId) = self { return entryId }
        return nil
    }
}

// MARK: - Log list

struct StudioMileageLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @ObservedObject private var settingsStore = SettingsStore.shared

    var highlightEntryID: UUID? = nil

    @State private var mileageSheetMode: MileageSheetMode?
    @State private var didOpenHighlight = false

    private var summary: MileageSummaryDisplay {
        studioBrain.mileageSummaryDisplay()
    }

    var body: some View {
        StudioThemedListBackdrop {
            mileageContentList
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarButton(
                    systemName: "plus",
                    accessibilityLabel: BuxCatalogLabel.string(
                        "Add mileage entry",
                        locale: appSettingsManager.interfaceLocale
                    ),
                    action: { mileageSheetMode = .add(openToken: UUID()) }
                )
            }
        }
        .sheet(item: $mileageSheetMode) { mode in
            MileageEntrySheet(
                mode: mode,
                countryCode: appSettingsManager.selectedCountry.id,
                proRouteFeatures: settingsStore.studioMode == .pro,
                onSave: { outbound, returnLeg in
                    switch mode {
                    case .edit:
                        store.updateMileageEntry(outbound)
                    case .add:
                        store.addMileageEntry(outbound)
                    }
                    if let returnLeg {
                        store.addMileageEntry(returnLeg)
                    }
                    refreshAfterMileageChange()
                }
            )
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .buxStudioSheetContent()
        }
        .onAppear(perform: openHighlightedEntryIfNeeded)
    }

    private func openHighlightedEntryIfNeeded() {
        guard !didOpenHighlight, let highlightEntryID else { return }
        guard store.mileageEntries.contains(where: { $0.id == highlightEntryID }) else { return }
        didOpenHighlight = true
        mileageSheetMode = .edit(highlightEntryID)
    }

    @ViewBuilder
    private var mileageLogScreenHeader: some View {
        if settingsStore.studioMode == .pro {
            StudioProToolScreenHeader(titleKey: "Mileage Log")
        } else {
            StudioSimpleToolScreenHeader(titleKey: "Mileage Log")
        }
    }

    private var mileageContentList: some View {
        List {
            Section {
                mileageLogScreenHeader
                    .studioProToolScreenHeaderRow()
            }

            if store.mileageEntries.isEmpty {
                Section {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else {
                if summary.entryCount > 0 {
                    Section {
                        mileageSummaryCard
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(MileageBrain.sortedEntries(store.mileageEntries)) { entry in
                    Button {
                        mileageSheetMode = .edit(entry.id)
                    } label: {
                        mileageRowCard(entry)
                    }
                    .studioThemedListRowChrome()
                    .contextMenu {
                        Button {
                            addReturnTrip(from: entry)
                        } label: {
                            Label {
                                Text(BuxCatalogLabel.string(
                                    "Same trip back",
                                    locale: appSettingsManager.interfaceLocale
                                ))
                            } icon: {
                                Image(systemName: "arrow.left.arrow.right.circle")
                            }
                        }
                    }
                }
                .onDelete(perform: deleteEntries)
            }
        }
        .studioProToolScrollTopInset()
        .studioThemedListRows()
    }

    private var mileageSummaryCard: some View {
        HStack(spacing: BuxLayout.section) {
            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogDynamicText(key: "BUSINESS TOTAL")
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()
                Text(summary.businessDistanceFormatted)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                BuxCatalogDynamicText(key: "ALLOWANCE")
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()
                Text(summary.deductionFormatted)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
        }
        .studioThemedListRowCard()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 40))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme).opacity(0.8))
            BuxCatalogDynamicText(key: "No trips logged yet")
                .font(.system(size: 16, weight: .semibold))
            BuxCatalogDynamicText(key: "Add business mileage to include allowances in your deduction estimate.")
                .font(.system(size: 13))
                .buxLabelSecondary()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            BuxButton(
                title: "Log trip",
                systemImage: "car.fill",
                role: .primary,
                size: .regular
            ) {
                mileageSheetMode = .add(openToken: UUID())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .studioHubEmbeddedHorizontalPadding()
    }

    private func mileageRowCard(_ entry: MileageEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                    .fill(themeManager.current.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "car.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(routeLabel(entry))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(entry.purpose.catalogLabel(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(purposeColor(entry.purpose))
                    if let fuel = entry.fuelType {
                        HStack(spacing: 3) {
                            Image(systemName: fuel.systemImage)
                                .font(.system(size: 9, weight: .bold))
                            Text(fuel.catalogLabel(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(MileageBrain.formatDistance(entry.distance))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                Text(entry.date, style: .date)
                    .font(.system(size: 11))
                    .buxLabelSecondary()
            }
        }
        .studioThemedListRowCard()
    }

    private func routeLabel(_ entry: MileageEntry) -> String {
        let start = entry.startLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = entry.endLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if start.isEmpty && end.isEmpty {
            return BuxCatalogLabel.string("Trip", locale: appSettingsManager.interfaceLocale)
        }
        if start.isEmpty { return end }
        if end.isEmpty { return start }
        return "\(start) → \(end)"
    }

    private func purposeColor(_ purpose: MileagePurpose) -> Color {
        switch purpose {
        case .business: return .green
        case .personal: return .orange
        case .pleasure: return .purple
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let sorted = MileageBrain.sortedEntries(store.mileageEntries)
        for index in offsets {
            store.deleteMileageEntry(id: sorted[index].id)
        }
        refreshAfterMileageChange()
    }

    private func addReturnTrip(from outbound: MileageEntry) {
        let returnLeg = MileageBrain.returnTrip(from: outbound)
        store.addMileageEntry(returnLeg)
        refreshAfterMileageChange()
    }

    private func refreshAfterMileageChange() {
        studioBrain.refreshDeductions()
        studioBrain.refreshIncomeTax()
        studioBrain.refreshAll()
    }
}

// MARK: - Mileage trip field focus

private enum MileageTripField: Hashable {
    case start
    case end
    case distance
    case notes
}

// MARK: - Address autocomplete field

private struct MileageAddressSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let title: String
    @Binding var text: String
    @ObservedObject var autocomplete: MileageAddressAutocompleteModel
    let onSelect: (MileageResolvedPlace) -> Void
    var onTextEdited: (() -> Void)?
    var onUseCurrentLocation: (() -> Void)?
    var showLocationButton: Bool = false
    var focusedField: FocusState<MileageTripField?>.Binding
    let focusValue: MileageTripField

    @State private var isResolvingAddresses = false
    @State private var addressLookupErrorKey: String?
    @State private var suppressTextEdited = false

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc(title).uppercased())
                .font(.system(size: 10, weight: .bold))
                .buxLabelSecondary()

            HStack(spacing: 8) {
                TextField(loc("Address or postcode"), text: $text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: focusValue)
                    .submitLabel(.search)
                    .onSubmit {
                        resolveTypedAddress()
                    }
                    .onChange(of: text) { _, value in
                        if suppressTextEdited {
                            suppressTextEdited = false
                            return
                        }
                        addressLookupErrorKey = nil
                        autocomplete.updateQuery(value)
                        onTextEdited?()
                    }

                if !text.isEmpty {
                    Button {
                        clearField()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(loc("Clear"))
                }

                if showLocationButton, let onUseCurrentLocation {
                    Button(action: onUseCurrentLocation) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
            }

            if isResolvingAddresses {
                HStack(spacing: 8) {
                    ProgressView()
                    BuxCatalogDynamicText(key: "Loading addresses…")
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }

            if let addressLookupErrorKey {
                Text(loc(addressLookupErrorKey))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !autocomplete.completions.isEmpty {
                VStack(spacing: 0) {
                    BuxCatalogDynamicText(key: "Keep typing a house number, name, or business — or pick from the list.")
                        .font(.system(size: 10, weight: .medium))
                        .buxLabelSecondary()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    ForEach(Array(autocomplete.completions.prefix(15).enumerated()), id: \.offset) { _, completion in
                        Button {
                            select(completion)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                                        .multilineTextAlignment(.leading)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.system(size: 11))
                                            .buxLabelSecondary()
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if completion.title != autocomplete.completions.prefix(15).last?.title {
                            Divider().opacity(0.12)
                        }
                    }
                }
                .studioThemedCardChrome(cornerRadius: 14)
            }
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        focusedField.wrappedValue = nil
        autocomplete.clear()
        addressLookupErrorKey = nil
        resolveAndApply(completion)
    }

    private func resolveAndApply(_ completion: MKLocalSearchCompletion) {
        isResolvingAddresses = true
        Task {
            let place = await MileageRouteBrain.resolve(
                completion: completion,
                countryCode: autocomplete.countryCode,
                interfaceLocale: locale
            )
            await MainActor.run {
                isResolvingAddresses = false
                if let place {
                    applyPlace(place)
                } else {
                    addressLookupErrorKey =
                        "No street addresses found for this postcode. Type a house number or use postcode area only."
                }
            }
        }
    }

    private func applyPlace(_ place: MileageResolvedPlace) {
        isResolvingAddresses = false
        onSelect(place)
        setTextProgrammatically(place.label)
        Task {
            let localized = await MileageRouteBrain.relabelSelectedPlace(
                place,
                interfaceLocale: locale,
                countryCode: autocomplete.countryCode
            )
            await MainActor.run {
                guard localized.id == place.id else { return }
                setTextProgrammatically(localized.label)
            }
        }
    }

    private func setTextProgrammatically(_ value: String) {
        suppressTextEdited = true
        text = value
    }

    private func clearField() {
        text = ""
        addressLookupErrorKey = nil
        isResolvingAddresses = false
        autocomplete.clear()
        onTextEdited?()
    }

    private func resolveTypedAddress() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        focusedField.wrappedValue = nil
        autocomplete.clear()
        isResolvingAddresses = true
        addressLookupErrorKey = nil
        Task {
            let place = await MileageRouteBrain.resolve(
                query: query,
                countryCode: autocomplete.countryCode,
                interfaceLocale: locale
            )
            await MainActor.run {
                isResolvingAddresses = false
                if let place {
                    applyPlace(place)
                } else {
                    addressLookupErrorKey =
                        "No street addresses found for this postcode. Type a house number or use postcode area only."
                }
            }
        }
    }
}

// MARK: - Entry sheet

struct MileageEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    @ObservedObject private var settingsStore = SettingsStore.shared
    @StateObject private var locationCapture = MileageLocationCapture()
    @StateObject private var startAutocomplete = MileageAddressAutocompleteModel()
    @StateObject private var endAutocomplete = MileageAddressAutocompleteModel()

    let mode: MileageSheetMode
    let countryCode: String
    var proRouteFeatures: Bool = false
    /// Outbound entry, then optional return leg when logging there-and-back in one save.
    let onSave: (_ outbound: MileageEntry, _ returnLeg: MileageEntry?) -> Void

    @State private var includeReturnJourney = false
    @State private var date = Date()
    @State private var distanceText = ""
    @State private var distanceManuallyEdited = false
    @State private var startLocation = ""
    @State private var endLocation = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var purpose: MileagePurpose = .business
    @State private var notes = ""
    @State private var isCalculatingRoute = false
    @State private var routeErrorKey: String?
    @State private var routeOptions: [MileageRouteOption] = []
    @State private var selectedRouteID: Int?
    @State private var selectedRouteName: String?
    @State private var fuelType: MileageFuelType?
    @State private var suppressDistanceManualEdit = false

    @FocusState private var focusedField: MileageTripField?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    private var isEditing: Bool { mode.editingEntryId != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                    .ignoresSafeArea(.keyboard, edges: .bottom)

                ScrollView {
                    VStack(spacing: BuxLayout.section) {
                        routeCard
                        if proRouteFeatures, let start = startCoordinate, let end = endCoordinate, !routeOptions.isEmpty {
                            MileageRoutePickerSection(
                                start: start,
                                end: end,
                                routes: routeOptions,
                                selectedRouteID: $selectedRouteID
                            )
                            .padding(BuxLayout.section)
                            .studioThemedCardChrome(cornerRadius: 20)
                            .onChange(of: selectedRouteID) { _, newValue in
                                applyRouteSelection(newValue)
                            }
                        }
                        if proRouteFeatures {
                            MileageFuelTypePickerSection(selection: $fuelType)
                                .padding(BuxLayout.section)
                                .studioThemedCardChrome(cornerRadius: 20)
                        }
                        distanceHero
                        purposePicker
                        if !isEditing, canLogReturnLeg {
                            returnJourneyToggle
                        }
                        dateNotesSection
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, BuxLayout.tight)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .buxCatalogNavigationTitle(isEditing ? "Edit Trip" : "Log Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: loc("Save"),
                        isEnabled: parsedDistance > 0
                    ) {
                        save(includeReturn: false)
                    }
                }
                if isEditing, canLogReturnLeg {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            save(includeReturn: true)
                        } label: {
                            VStack(spacing: 2) {
                                BuxCatalogDynamicText(key: "Log same trip back")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Adds the drive home (From ↔ To swapped)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .buxStableNavigationBarWithKeyboard()
            .buxStudioSheetContent()
            .onAppear {
                startAutocomplete.configure(countryCode: countryCode, interfaceLocale: locale)
                endAutocomplete.configure(countryCode: countryCode, interfaceLocale: locale)
                reloadFormFromStore()
            }
            .onChange(of: mode.id) { _, _ in
                reloadFormFromStore()
            }
            .onChange(of: store.mileageEntries) { _, _ in
                guard isEditing else { return }
                reloadFormFromStore()
            }
        }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            MileageAddressSearchField(
                title: "From",
                text: $startLocation,
                autocomplete: startAutocomplete,
                onSelect: { place in
                    startCoordinate = place.coordinate
                    recalculateRouteIfPossible()
                },
                onTextEdited: clearStartRouteState,
                onUseCurrentLocation: startLocationCaptureAction,
                showLocationButton: settingsStore.autoLocationForMileage,
                focusedField: $focusedField,
                focusValue: .start
            )

            MileageAddressSearchField(
                title: "To",
                text: $endLocation,
                autocomplete: endAutocomplete,
                onSelect: { place in
                    endCoordinate = place.coordinate
                    recalculateRouteIfPossible()
                },
                onTextEdited: clearEndRouteState,
                onUseCurrentLocation: endLocationCaptureAction,
                showLocationButton: settingsStore.autoLocationForMileage,
                focusedField: $focusedField,
                focusValue: .end
            )

            if isCalculatingRoute {
                HStack(spacing: 8) {
                    ProgressView()
                    BuxCatalogDynamicText(key: "Calculating driving distance…")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
            } else if let routeErrorKey {
                Text(loc(routeErrorKey))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 20)
    }

    private var distanceHero: some View {
        VStack(spacing: 8) {
            BuxCatalogDynamicText(key: "DISTANCE")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0.0", text: $distanceText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 160)
                    .focused($focusedField, equals: .distance)
                    .onChange(of: distanceText) { _, _ in
                        guard !suppressDistanceManualEdit else { return }
                        distanceManuallyEdited = true
                    }
                BuxCatalogDynamicText(key: "mi")
                    .font(.system(size: 20, weight: .semibold))
                    .buxLabelSecondary()
            }
            if purpose == .business, parsedDistance > 0 {
                Text(
                    BuxLocalizedString.format(
                        "Est. allowance: %@",
                        locale: appSettingsManager.interfaceLocale,
                        estimatedAllowanceFormatted
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .studioThemedCardChrome(cornerRadius: 24)
    }

    private var purposePicker: some View {
        Picker(loc("Purpose"), selection: $purpose) {
            ForEach(MileagePurpose.allCases) { p in
                Text(p.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .padding(BuxLayout.section)
        .buxFormSectionCard(cornerRadius: 16)
    }

    private var canLogReturnLeg: Bool {
        parsedDistance > 0
            && (!startLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !endLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var returnJourneyToggle: some View {
        Toggle(isOn: $includeReturnJourney) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    BuxCatalogDynamicText(key: "There and back")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(
                    BuxLocalizedString.format(
                        "Same trip home — adds a second log with From ↔ To swapped (%@ mi each way).",
                        locale: appSettingsManager.interfaceLocale,
                        formattedReturnDistance
                    )
                )
                    .font(.system(size: 11))
                    .buxLabelSecondary()
                if includeReturnJourney, canShowReturnRoutePreview {
                    Text(returnRoutePreview)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme).opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .padding(BuxLayout.section)
        .buxFormSectionCard(cornerRadius: 16)
    }

    private var dateNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(loc("Date"), selection: $date, displayedComponents: .date)
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            TextField(BuxCatalogLabel.string("Notes (optional)", locale: appSettingsManager.interfaceLocale), text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .focused($focusedField, equals: .notes)
        }
        .padding(BuxLayout.section)
        .buxFormSectionCard(cornerRadius: 20)
    }

    private var canShowReturnRoutePreview: Bool {
        !startLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !endLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var returnRoutePreview: String {
        let from = startLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = endLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let outbound = routePreviewLabel(from: from, to: to)
        let inbound = routePreviewLabel(from: to, to: from)
        let outboundLine = BuxLocalizedString.format("Outbound: %@", locale: locale, outbound)
        let backLine = BuxLocalizedString.format("Back: %@", locale: locale, inbound)
        return "\(outboundLine)\n\(backLine)"
    }

    private func routePreviewLabel(from: String, to: String) -> String {
        if from.isEmpty && to.isEmpty { return "—" }
        if from.isEmpty { return to }
        if to.isEmpty { return from }
        return "\(from) → \(to)"
    }

    private var formattedReturnDistance: String {
        String(format: "%.1f", parsedDistance)
    }

    private var parsedDistance: Double {
        Double(distanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var estimatedAllowanceFormatted: String {
        let allowance = Decimal(parsedDistance) * settingsStore.mileageRatePerUnit
        return appSettingsManager.format(allowance)
    }

    private var startLocationCaptureAction: (() -> Void)? {
        settingsStore.autoLocationForMileage ? { captureStartLocation() } : nil
    }

    private var endLocationCaptureAction: (() -> Void)? {
        settingsStore.autoLocationForMileage ? { captureEndLocation() } : nil
    }

    private func captureStartLocation() {
        locationCapture.captureCurrentLocation(forStart: true) { label in
            startLocation = label
            Task { await resolveTypedAddress(label, isStart: true) }
        }
    }

    private func captureEndLocation() {
        locationCapture.captureCurrentLocation(forStart: false) { label in
            endLocation = label
            Task { await resolveTypedAddress(label, isStart: false) }
        }
    }

    private func resolveTypedAddress(_ query: String, isStart: Bool) async {
        guard let resolved = await MileageRouteBrain.resolve(
            query: query,
            countryCode: countryCode,
            interfaceLocale: locale
        ) else { return }
        await MainActor.run {
            if isStart {
                startLocation = resolved.label
                startCoordinate = resolved.coordinate
            } else {
                endLocation = resolved.label
                endCoordinate = resolved.coordinate
            }
            recalculateRouteIfPossible()
        }
    }

    private func recalculateRouteIfPossible(preferredRouteID: Int? = nil) {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        routeErrorKey = nil
        isCalculatingRoute = true
        routeOptions = []
        selectedRouteID = nil
        selectedRouteName = nil
        Task {
            if proRouteFeatures {
                let options = await MileageRouteBrain.drivingRouteOptions(from: start, to: end)
                await MainActor.run {
                    isCalculatingRoute = false
                    guard !options.isEmpty else {
                        routeErrorKey = "Could not calculate a route. Enter distance manually."
                        return
                    }
                    routeOptions = options
                    let routeID = preferredRouteID.flatMap { id in
                        options.contains(where: { $0.id == id }) ? id : nil
                    } ?? options.first?.id
                    selectedRouteID = routeID
                    applyRouteSelection(routeID)
                }
            } else {
                let miles = await MileageRouteBrain.drivingDistanceMiles(from: start, to: end)
                await MainActor.run {
                    isCalculatingRoute = false
                    if let miles, miles > 0 {
                        if !distanceManuallyEdited {
                            suppressDistanceManualEdit = true
                            distanceText = String(format: "%.1f", miles)
                            suppressDistanceManualEdit = false
                        }
                    } else {
                        routeErrorKey = "Could not calculate a route. Enter distance manually."
                    }
                }
            }
        }
    }

    private func clearStartRouteState() {
        startCoordinate = nil
        clearPendingRouteState()
    }

    private func clearEndRouteState() {
        endCoordinate = nil
        clearPendingRouteState()
    }

    private func clearPendingRouteState() {
        routeOptions = []
        selectedRouteID = nil
        selectedRouteName = nil
        isCalculatingRoute = false
        routeErrorKey = nil
    }

    private func applyRouteSelection(_ routeID: Int?) {
        guard let routeID,
              let route = routeOptions.first(where: { $0.id == routeID }) else { return }
        selectedRouteName = route.name
        suppressDistanceManualEdit = true
        distanceText = String(format: "%.1f", route.distanceMiles)
        suppressDistanceManualEdit = false
        if proRouteFeatures {
            distanceManuallyEdited = false
        }
    }

    private func reloadFormFromStore() {
        guard let entryId = mode.editingEntryId else {
            resetFormForNewTrip()
            return
        }
        guard let entry = store.mileageEntries.first(where: { $0.id == entryId }) else { return }
        applyEntryToForm(entry)
    }

    private func resetFormForNewTrip() {
        includeReturnJourney = false
        date = Date()
        distanceText = ""
        distanceManuallyEdited = false
        startLocation = ""
        endLocation = ""
        startCoordinate = nil
        endCoordinate = nil
        purpose = .business
        notes = ""
        isCalculatingRoute = false
        routeErrorKey = nil
        routeOptions = []
        selectedRouteID = nil
        selectedRouteName = nil
        fuelType = nil
    }

    private func applyEntryToForm(_ entry: MileageEntry) {
        date = entry.date
        distanceText = entry.distance > 0 ? String(format: "%.1f", entry.distance) : ""
        distanceManuallyEdited = true
        startLocation = entry.startLocation
        endLocation = entry.endLocation
        startCoordinate = entry.startCoordinate
        endCoordinate = entry.endCoordinate
        purpose = entry.purpose
        notes = entry.notes
        fuelType = entry.fuelType
        selectedRouteID = entry.selectedRouteIndex
        selectedRouteName = entry.selectedRouteName
        includeReturnJourney = false
        isCalculatingRoute = false
        routeErrorKey = nil
        routeOptions = []
        if proRouteFeatures, entry.startCoordinate != nil, entry.endCoordinate != nil {
            recalculateRouteIfPossible(preferredRouteID: entry.selectedRouteIndex)
        }
    }

    private func buildOutboundEntry() -> MileageEntry {
        var entry: MileageEntry
        if let entryId = mode.editingEntryId,
           let existing = store.mileageEntries.first(where: { $0.id == entryId }) {
            entry = existing
        } else {
            entry = MileageEntry()
        }
        entry.date = date
        entry.distance = parsedDistance
        entry.startLocation = startLocation
        entry.endLocation = endLocation
        entry.purpose = purpose
        entry.notes = notes
        entry.setStartCoordinate(startCoordinate)
        entry.setEndCoordinate(endCoordinate)
        if proRouteFeatures {
            entry.fuelType = fuelType
            entry.selectedRouteIndex = selectedRouteID
            entry.selectedRouteName = selectedRouteName
        }
        return entry
    }

    private func save(includeReturn: Bool) {
        let outbound = buildOutboundEntry()
        let shouldAddReturn = includeReturn
            || (!isEditing && includeReturnJourney)
        let returnLeg = shouldAddReturn ? MileageBrain.returnTrip(from: outbound, on: date) : nil
        onSave(outbound, returnLeg)
        dismiss()
    }
}
