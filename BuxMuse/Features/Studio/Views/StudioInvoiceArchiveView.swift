//
//  StudioInvoiceArchiveView.swift
//  BuxMuse
//
//  Studio tools — backup, export, and delete Simple + Pro invoices on-device.
//

import SwiftUI

struct StudioInvoiceArchiveView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @State private var isSelecting = false
    @State private var selectedSimpleIDs: Set<UUID> = []
    @State private var selectedProIDs: Set<UUID> = []
    @State private var showExportSheet = false
    @State private var includeReceiptPhotos = false
    @State private var archiveExportPhase: ArchiveExportPhase = .idle
    @State private var exportURL: URL?

    private enum ArchiveExportPhase {
        case idle, building, complete
    }

    private var isArchiveBusy: Bool { archiveExportPhase != .idle }
    @State private var exportError: String?
    @State private var showDeleteConfirm = false
    @State private var deleteIncludesLinkedTwin = false

    private var locale: Locale { appSettingsManager.interfaceLocale }
    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    private var simpleRows: [StudioInvoiceArchiveRow] {
        StudioInvoiceArchiveEngine.simpleRows(simpleStore: simpleStudioStore, studioStore: studioStore)
    }

    private var proRows: [StudioInvoiceArchiveRow] {
        StudioInvoiceArchiveEngine.proRows(simpleStore: simpleStudioStore, studioStore: studioStore)
    }

    private var hasAnyInvoices: Bool { !simpleRows.isEmpty || !proRows.isEmpty }
    private var selectedCount: Int { selectedSimpleIDs.count + selectedProIDs.count }

    private var canCreateZIP: Bool {
        if isArchiveBusy { return false }
        if includeReceiptPhotos { return true }
        if isSelecting { return selectedCount > 0 }
        return hasAnyInvoices
    }

    var body: some View {
        StudioThemedListBackdrop {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxTokens.block) {
                        StudioProToolScreenHeader(titleKey: "Backup invoices")
                            .studioProToolScrollPlacement()

                        Group {
                            heroCard

                            if !hasAnyInvoices {
                                emptyStateCard
                            } else {
                                if !simpleRows.isEmpty {
                                    tierSection(
                                        titleKey: "Simple Studio",
                                        icon: "leaf.fill",
                                        tint: .orange,
                                        rows: simpleRows
                                    )
                                }
                                if !proRows.isEmpty {
                                    tierSection(
                                        titleKey: "Pro Studio",
                                        icon: "sparkles",
                                        tint: accent,
                                        rows: proRows
                                    )
                                }
                            }

                            privacyFootnote
                        }
                        .buxPadStudioSectionInset()
                    }
                    .padding(.bottom, 100)
                }
                .studioProToolScrollTopInset()
                .buxSoftScrollChrome()

                exportFAB
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .toolbar { navigationToolbar }
        .sheet(isPresented: $showExportSheet) { exportOptionsSheet }
        .alert(
            BuxCatalogLabel.string("Export failed", locale: locale),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button(BuxCatalogLabel.string("OK", locale: locale), role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .confirmationDialog(
            BuxCatalogLabel.string("Delete invoices?", locale: locale),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(BuxCatalogLabel.string("Delete", locale: locale), role: .destructive) {
                performBulkDelete()
            }
            Button(BuxCatalogLabel.string("Cancel", locale: locale), role: .cancel) {}
        } message: {
            if deleteIncludesLinkedTwin {
                BuxCatalogDynamicText(
                    key: "Removes the selected Simple or Pro copies only. Linked invoices in the other tier stay on this device."
                )
            } else {
                BuxCatalogDynamicText(key: "Selected invoices will be removed from this device. This cannot be undone.")
            }
        }
        .buxInterfaceLocale()
    }

    // MARK: - Hero

    private var heroCard: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "doc.text.image.fill")
                        .foregroundStyle(accent)
                }

                VStack(spacing: 6) {
                    BuxCatalogDynamicText(key: "Your invoice vault")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)

                    BuxCatalogDynamicText(
                        key: "Export PDF + PNG backups on this device. Add receipt photos only if you want them."
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    if hasAnyInvoices {
                        HStack(spacing: 8) {
                            statChip(count: simpleRows.count, labelKey: "Simple", tint: .orange)
                            statChip(count: proRows.count, labelKey: "Pro", tint: accent)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statChip(count: Int, labelKey: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            BuxCatalogDynamicText(key: labelKey)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
        .clipShape(Capsule())
    }

    // MARK: - Empty state

    private var emptyStateCard: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(spacing: BuxTokens.section) {
                Image(systemName: "tray")
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .imageScale(.large)

                VStack(spacing: 6) {
                    BuxCatalogDynamicText(key: "No invoices yet")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    BuxCatalogDynamicText(
                        key: "Create invoices in Simple or Pro Studio, then export PDF and PNG backups here. You can also include receipt photos when you export."
                    )
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }

                Button {
                    includeReceiptPhotos = true
                    showExportSheet = true
                } label: {
                    Label {
                        BuxCatalogDynamicText(key: "Export receipt photos only")
                    } icon: {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Tier sections

    private func tierSection(
        titleKey: String,
        icon: String,
        tint: Color,
        rows: [StudioInvoiceArchiveRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            HStack(spacing: 8) {
                Label {
                    EmptyView()
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                }
                .labelStyle(.iconOnly)

                BuxCatalogDynamicText(key: titleKey)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                Spacer()
                Text("\(rows.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.85))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    invoiceRowCard(row, tint: tint)
                }
            }
        }
    }

    private func invoiceRowCard(_ row: StudioInvoiceArchiveRow, tint: Color) -> some View {
        let isSelected = row.tier == .simple
            ? selectedSimpleIDs.contains(row.id)
            : selectedProIDs.contains(row.id)

        return Button {
            if isSelecting {
                toggleSelection(row)
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                selectionMarker(isSelected: isSelected)
                    .frame(width: 28, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: row.tier == .simple ? "doc.plaintext.fill" : "doc.richtext.fill")
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.customerName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            statusCapsule(for: row)
                            if row.hasLinkedTwin { linkedBadge }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            statusCapsule(for: row)
                            if row.hasLinkedTwin { linkedBadge }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(appSettingsManager.format(row.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .layoutPriority(1)
            }
            .studioThemedListRowCard()
            .overlay {
                if isSelecting && isSelected {
                    RoundedRectangle(cornerRadius: StudioListMetrics.rowCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.55), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func selectionMarker(isSelected: Bool) -> some View {
        if isSelecting {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? accent : themeManager.labelTertiary(for: colorScheme))
                .symbolRenderingMode(.hierarchical)
        } else {
            Color.clear.frame(width: 22, height: 22)
        }
    }

    private var linkedBadge: some View {
        Label {
            BuxCatalogDynamicText(key: "Linked")
        } icon: {
            Image(systemName: "link")
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accent.opacity(colorScheme == .dark ? 0.2 : 0.1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func statusCapsule(for row: StudioInvoiceArchiveRow) -> some View {
        let (label, color): (String, Color) = {
            switch row.tier {
            case .simple:
                if let invoice = simpleStudioStore.invoice(id: row.id) {
                    return (invoice.status.catalogLabel(locale: locale), simpleStatusColor(invoice.status))
                }
            case .pro:
                if let invoice = studioStore.invoices.first(where: { $0.id == row.id }) {
                    return (invoice.status.catalogLabel(locale: locale), proStatusColor(invoice.status))
                }
            }
            return (row.statusLabel, themeManager.labelSecondary(for: colorScheme))
        }()

        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(colorScheme == .dark ? 0.22 : 0.14))
            .clipShape(Capsule())
    }

    private func simpleStatusColor(_ status: SimpleInvoiceStatus) -> Color {
        switch status {
        case .paid: return .green
        case .sent: return accent
        case .draft: return themeManager.labelSecondary(for: colorScheme)
        }
    }

    private func proStatusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .paid: return .green
        case .sent: return accent
        case .overdue: return .red
        case .cancelled: return themeManager.labelTertiary(for: colorScheme)
        case .draft: return accent.opacity(0.85)
        }
    }

    private var privacyFootnote: some View {
        Label {
            BuxCatalogDynamicText(
                key: "Exports stay on this device until you share them. Each invoice includes PDF and PNG. Optionally add receipt and scan photos to the same ZIP."
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(accent.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.field, style: .continuous)
                .fill(themeManager.accentWash(for: colorScheme).opacity(0.45))
        )
    }

    // MARK: - Toolbars

    private var exportFAB: some View {
        Button {
            showExportSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(accent, in: Circle())
                .shadow(color: accent.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isArchiveBusy)
        .padding(.trailing, BuxTokens.marginRegular)
        .padding(.bottom, BuxTokens.section)
        .accessibilityLabel(exportButtonTitle)
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelecting && hasAnyInvoices {
                Button(BuxCatalogLabel.string("Select all", locale: locale)) {
                    selectedSimpleIDs = Set(simpleRows.map(\.id))
                    selectedProIDs = Set(proRows.map(\.id))
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelecting && selectedCount > 0 {
                Button(BuxCatalogLabel.string("Delete", locale: locale), role: .destructive) {
                    prepareBulkDelete()
                }
            }

            if hasAnyInvoices {
                Button {
                    withAnimation(.buxCategorySpring) {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedSimpleIDs.removeAll()
                            selectedProIDs.removeAll()
                        }
                    }
                } label: {
                    Text(
                        isSelecting
                            ? BuxCatalogLabel.string("Done", locale: locale)
                            : BuxCatalogLabel.string("Select", locale: locale)
                    )
                }
            }
        }
    }

    private var exportButtonTitle: String {
        if isSelecting && selectedCount > 0 {
            return BuxCatalogLabel.string("Export selected", locale: locale)
        }
        return BuxCatalogLabel.string("Export", locale: locale)
    }

    // MARK: - Export sheet

    private var exportOptionsSheet: some View {
        NavigationStack {
            ZStack {
                BuxThemedCardForm {
                    BuxFormSection(title: "Export options") {
                        if isSelecting && selectedCount > 0 {
                            HStack {
                                BuxCatalogDynamicText(key: "Invoices selected")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text("\(selectedCount)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(accent)
                            }
                            .buxFormFieldPadding()
                            BuxFormRowDivider()
                        } else if isSelecting {
                            BuxCatalogDynamicText(key: "Select invoices to include, or turn on receipt photos.")
                                .font(.system(size: 14, weight: .medium))
                                .buxLabelSecondary()
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                        } else if hasAnyInvoices {
                            BuxCatalogDynamicText(key: "All invoices will be included.")
                                .font(.system(size: 14, weight: .medium))
                                .buxLabelSecondary()
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                        } else {
                            BuxCatalogDynamicText(key: "No invoices to include.")
                                .font(.system(size: 14, weight: .medium))
                                .buxLabelSecondary()
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                        }

                        Toggle(isOn: $includeReceiptPhotos) {
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogDynamicText(key: "Include receipt photos")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Adds Pro receipt images and Simple scan photos from this device.")
                                    .font(.system(size: 12, weight: .medium))
                                    .buxLabelSecondary()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(accent)
                        .buxFormFieldPadding()
                    }

                    if archiveExportPhase == .idle {
                        BuxFormSection(title: "How it works") {
                            Label {
                                BuxCatalogDynamicText(
                                    key: "Each invoice is exported as PDF and PNG. Use Share to save to Files, iCloud, or send to yourself."
                                )
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                                .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "doc.zipper")
                                    .foregroundStyle(accent)
                            }
                            .buxFormFieldPadding()
                        }

                        if let exportURL {
                            BuxFormSection(title: "Ready") {
                                ShareLink(item: exportURL) {
                                    HStack {
                                        Label {
                                            BuxCatalogDynamicText(key: "Share archive")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(accent)
                                        } icon: {
                                            Image(systemName: "square.and.arrow.up")
                                                .foregroundStyle(accent)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(themeManager.labelTertiary(for: colorScheme))
                                    }
                                }
                                .buxFormFieldPadding()
                            }
                        }
                    }
                }
                .opacity(isArchiveBusy ? 0 : 1)
                .allowsHitTesting(!isArchiveBusy)

                if archiveExportPhase == .building {
                    ArchiveZipBuildingIndicator(accent: accent)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                if archiveExportPhase == .complete {
                    ArchiveZipSuccessIndicator(accent: accent)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: archiveExportPhase)
            .navigationTitle(BuxCatalogLabel.string("Backup invoices", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Close", locale: locale)) {
                        showExportSheet = false
                        exportURL = nil
                    }
                    .disabled(isArchiveBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(BuxCatalogLabel.string("Create ZIP", locale: locale)) {
                        runExport()
                    }
                    .fontWeight(.bold)
                    .disabled(!canCreateZIP)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isArchiveBusy)
        .environmentObject(themeManager)
    }

    // MARK: - Actions

    private func toggleSelection(_ row: StudioInvoiceArchiveRow) {
        switch row.tier {
        case .simple:
            if selectedSimpleIDs.contains(row.id) { selectedSimpleIDs.remove(row.id) }
            else { selectedSimpleIDs.insert(row.id) }
        case .pro:
            if selectedProIDs.contains(row.id) { selectedProIDs.remove(row.id) }
            else { selectedProIDs.insert(row.id) }
        }
    }

    private func exportSimpleIDs() -> Set<UUID> {
        if isSelecting && !selectedSimpleIDs.isEmpty { return selectedSimpleIDs }
        if isSelecting && selectedSimpleIDs.isEmpty && !selectedProIDs.isEmpty { return [] }
        return Set(simpleRows.map(\.id))
    }

    private func exportProIDs() -> Set<UUID> {
        if isSelecting && !selectedProIDs.isEmpty { return selectedProIDs }
        if isSelecting && selectedProIDs.isEmpty && !selectedSimpleIDs.isEmpty { return [] }
        return Set(proRows.map(\.id))
    }

    private func runExport() {
        guard canCreateZIP else { return }
        exportURL = nil
        withAnimation(.easeInOut(duration: 0.35)) {
            archiveExportPhase = .building
        }
        Task { @MainActor in
            let started = ContinuousClock.now
            do {
                let url = try StudioInvoiceArchiveEngine.exportToTemporaryZIP(
                    simpleIDs: exportSimpleIDs(),
                    proIDs: exportProIDs(),
                    includeReceiptPhotos: includeReceiptPhotos,
                    simpleStore: simpleStudioStore,
                    studioStore: studioStore,
                    themeManager: themeManager,
                    appSettings: appSettingsManager
                )
                let elapsed = started.duration(to: ContinuousClock.now)
                let minimumBuild: Duration = .seconds(1.4)
                if elapsed < minimumBuild {
                    try await Task.sleep(for: minimumBuild - elapsed)
                }
                exportURL = url
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    archiveExportPhase = .complete
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeInOut(duration: 0.35)) {
                    archiveExportPhase = .idle
                }
            } catch {
                archiveExportPhase = .idle
                exportError = error.localizedDescription
            }
        }
    }

    private func prepareBulkDelete() {
        let simpleLinked = simpleRows.filter { selectedSimpleIDs.contains($0.id) && $0.hasLinkedTwin }
        let proLinked = proRows.filter { selectedProIDs.contains($0.id) && $0.hasLinkedTwin }
        deleteIncludesLinkedTwin = !simpleLinked.isEmpty || !proLinked.isEmpty
        showDeleteConfirm = true
    }

    private func performBulkDelete() {
        for id in selectedSimpleIDs { simpleStudioStore.deleteInvoice(id: id) }
        for id in selectedProIDs { studioStore.deleteInvoice(id: id) }
        selectedSimpleIDs.removeAll()
        selectedProIDs.removeAll()
        isSelecting = false
    }
}

private struct ArchiveZipBuildingIndicator: View {
    let accent: Color
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 56))
                .foregroundStyle(accent)
                .scaleEffect(pulse ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

            ProgressView()
                .controlSize(.large)

            BuxCatalogDynamicText(key: "Building archive…")
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}

private struct ArchiveZipSuccessIndicator: View {
    let accent: Color
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(.green)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)

            Image(systemName: "doc.zipper")
                .font(.system(size: 44))
                .foregroundStyle(accent)

            BuxCatalogDynamicText(key: "Archive ready")
                .font(.system(size: 18, weight: .bold))

            BuxCatalogDynamicText(key: "Your ZIP is ready to share.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }
}
