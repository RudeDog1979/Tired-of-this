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

    @State private var mileageSheetMode: MileageSheetMode?

    private var summary: MileageSummaryDisplay {
        studioBrain.mileageSummaryDisplay()
    }

    var body: some View {
        StudioThemedListBackdrop {
            if store.mileageEntries.isEmpty {
                emptyState
            } else {
                mileageList
            }
        }
        .navigationTitle("Mileage Log")
        .navigationBarTitleDisplayMode(.large)
        .buxRootNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarButton(
                    systemName: "plus",
                    accessibilityLabel: "Add mileage entry",
                    action: { mileageSheetMode = .add(openToken: UUID()) }
                )
            }
        }
        .sheet(item: $mileageSheetMode) { mode in
            MileageEntrySheet(
                mode: mode,
                countryCode: appSettingsManager.selectedCountry.id,
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
    }

    private var mileageList: some View {
        List {
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
                        Label("Same trip back", systemImage: "arrow.left.arrow.right.circle")
                    }
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .contentMargins(.top, BuxLayout.invoicesNavChromeScrollInset, for: .scrollContent)
        .studioThemedListRows()
    }

    private var mileageSummaryCard: some View {
        HStack(spacing: BuxLayout.section) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BUSINESS TOTAL")
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()
                Text(summary.businessDistanceFormatted)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("ALLOWANCE")
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
                .foregroundColor(themeManager.current.accentColor.opacity(0.8))
            Text("No trips logged yet")
                .font(.system(size: 16, weight: .semibold))
            Text("Add business mileage to include allowances in your deduction estimate.")
                .font(.system(size: 13))
                .buxLabelSecondary()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Log trip") {
                mileageSheetMode = .add(openToken: UUID())
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.current.accentColor)
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
                    .foregroundColor(themeManager.current.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(routeLabel(entry))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(2)
                Text(entry.purpose.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(purposeColor(entry.purpose))
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
        if start.isEmpty && end.isEmpty { return "Trip" }
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

    let title: String
    @Binding var text: String
    @ObservedObject var autocomplete: MileageAddressAutocompleteModel
    let onSelect: (MileageResolvedPlace) -> Void
    var onUseCurrentLocation: (() -> Void)?
    var showLocationButton: Bool = false
    var focusedField: FocusState<MileageTripField?>.Binding
    let focusValue: MileageTripField

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .buxLabelSecondary()

            HStack(spacing: 8) {
                TextField("Address or postcode", text: $text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: focusValue)
                    .onChange(of: text) { _, value in
                        autocomplete.updateQuery(value)
                    }

                if showLocationButton, let onUseCurrentLocation {
                    Button(action: onUseCurrentLocation) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(themeManager.current.accentColor)
                }
            }

            if focusedField.wrappedValue == focusValue, !autocomplete.completions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(autocomplete.completions.prefix(6).enumerated()), id: \.offset) { _, completion in
                        Button {
                            select(completion)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(themeManager.current.accentColor)
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

                        if completion.title != autocomplete.completions.last?.title {
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
        Task {
            if let resolved = await MileageRouteBrain.resolve(completion: completion) {
                await MainActor.run {
                    text = resolved.label
                    onSelect(resolved)
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
    @State private var routeError: String?

    @FocusState private var focusedField: MileageTripField?

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
            .navigationTitle(isEditing ? "Edit Trip" : "Log Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: "Save",
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
                                Text("Log same trip back")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Adds the drive home (From ↔ To swapped)")
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
                startAutocomplete.configure(countryCode: countryCode)
                endAutocomplete.configure(countryCode: countryCode)
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
                onUseCurrentLocation: endLocationCaptureAction,
                showLocationButton: settingsStore.autoLocationForMileage,
                focusedField: $focusedField,
                focusValue: .end
            )

            if isCalculatingRoute {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Calculating driving distance…")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
            } else if let routeError {
                Text(routeError)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 20)
    }

    private var distanceHero: some View {
        VStack(spacing: 8) {
            Text("DISTANCE")
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
                        distanceManuallyEdited = true
                    }
                Text("mi")
                    .font(.system(size: 20, weight: .semibold))
                    .buxLabelSecondary()
            }
            if purpose == .business, parsedDistance > 0 {
                Text("Est. allowance: \(estimatedAllowanceFormatted)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .studioThemedCardChrome(cornerRadius: 24)
    }

    private var purposePicker: some View {
        Picker("Purpose", selection: $purpose) {
            ForEach(MileagePurpose.allCases) { p in
                Text(p.displayName).tag(p)
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
                        .foregroundColor(themeManager.current.accentColor)
                    Text("There and back")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Same trip home — adds a second log with From ↔ To swapped (\(formattedReturnDistance) mi each way).")
                    .font(.system(size: 11))
                    .buxLabelSecondary()
                if includeReturnJourney, canShowReturnRoutePreview {
                    Text(returnRoutePreview)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.current.accentColor.opacity(0.9))
                }
            }
        }
        .tint(themeManager.current.accentColor)
        .padding(BuxLayout.section)
        .buxFormSectionCard(cornerRadius: 16)
    }

    private var dateNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .tint(themeManager.current.accentColor)
            TextField("Notes (optional)", text: $notes, axis: .vertical)
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
        return "Outbound: \(outbound)\nBack: \(inbound)"
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
        guard let resolved = await MileageRouteBrain.resolve(query: query, countryCode: countryCode) else { return }
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

    private func recalculateRouteIfPossible() {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        routeError = nil
        isCalculatingRoute = true
        Task {
            let miles = await MileageRouteBrain.drivingDistanceMiles(from: start, to: end)
            await MainActor.run {
                isCalculatingRoute = false
                if let miles, miles > 0 {
                    if !distanceManuallyEdited {
                        distanceText = String(format: "%.1f", miles)
                    }
                } else {
                    routeError = "Could not calculate a route. Enter distance manually."
                }
            }
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
        routeError = nil
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
        includeReturnJourney = false
        isCalculatingRoute = false
        routeError = nil
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
