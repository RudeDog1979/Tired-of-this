//
//  TaxEnvelopeRootView.swift
//  BuxMuse
//

import SwiftUI

enum TaxEnvelopeTab: String, CaseIterable, Identifiable {
    case week
    case jar
    case reminders

    var id: String { rawValue }

    func label(locale: Locale) -> String {
        switch self {
        case .week: return BuxCatalogLabel.string("This week", locale: locale)
        case .jar: return BuxCatalogLabel.string("My set-aside", locale: locale)
        case .reminders: return BuxCatalogLabel.string("Due soon", locale: locale)
        }
    }
}

struct TaxEnvelopeRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var appDataManager: AppDataManager

    @State private var selectedTab: TaxEnvelopeTab = .week
    @State private var showOnboarding = false
    @State private var showManualDeposit = false
    @State private var yearPacketShare: BuxPDFSharePayload?
    @State private var showYearSummaryPreview = false

    private var display: TaxEnvelopeRootDisplay { taxEnvelopeBrain.display }
    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        ZStack {
            if usesPadSplitLayout {
                BuxLandingTintBackground()
                    .ignoresSafeArea()
            } else {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: BuxTokens.block) {
                header
                paymentScheduleCard
                tabPicker
                tabContent
                footerActions
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.top, BuxTokens.tight)
        }
        .buxCatalogNavigationTitle("Tax savings")
        .buxInterfaceLocale()
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .onAppear {
            taxEnvelopeBrain.refreshAll()
            if display.needsOnboarding || !display.isEnabled {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            TaxEnvelopeOnboardingView { completed in
                if completed {
                    var envelope = studioStore.taxEnvelope
                    envelope.isEnabled = true
                    envelope.onboardingCompleted = true
                    studioStore.updateTaxEnvelope(envelope)
                }
                showOnboarding = false
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(taxEnvelopeBrain)
            .environmentObject(studioStore)
        }
        .sheet(isPresented: $showManualDeposit) {
            TaxEnvelopeManualDepositSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(studioStore)
                .onDisappear { taxEnvelopeBrain.refreshAll() }
        }
        .sheet(item: $yearPacketShare) { payload in
            BuxActivityShareSheet(items: payload.activityItems) {
                yearPacketShare = nil
            }
            .buxShareSheetPresentation()
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showYearSummaryPreview) {
            TaxEnvelopeYearSummaryPreviewSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(taxEnvelopeBrain)
        }
    }

    private var catalogPaymentDefault: String? {
        TaxCatalogProfileHydrator.catalogPaymentSchedule(
            countryCode: taxEnvelopeBrain.sourceContext().countryCode,
            regionCode: studioStore.taxProfile.regionCode
        )
    }

    private var paymentScheduleCard: some View {
        TaxEnvelopePaymentScheduleCard(
            selection: studioStore.taxProfile.paymentSchedule,
            catalogDefault: catalogPaymentDefault
        ) { schedule in
            var profile = studioStore.taxProfile
            profile.paymentSchedule = schedule
            studioStore.updateTaxProfile(profile)
            taxEnvelopeBrain.refreshAll()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Text(display.hubHero.yearProgressLine)
                .font(.system(size: 15, weight: .bold))
            Text(display.hubHero.disclaimer)
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
            if let taxYear = display.taxYearLabel {
                Text(taxYear)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
            }
            Text(display.countryLabel)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(TaxEnvelopeTab.allCases) { tab in
                Text(tab.label(locale: locale)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView(showsIndicators: false) {
            switch selectedTab {
            case .week:
                TaxEnvelopeWeekTab(
                    display: display.weekTab,
                    locale: locale,
                    onManualDeposit: { showManualDeposit = true }
                )
            case .jar:
                TaxEnvelopeJarTab(
                    display: display.jarTab,
                    locale: locale,
                    onManualDeposit: { showManualDeposit = true }
                )
            case .reminders:
                TaxEnvelopeRemindersTab(
                    display: display.remindersTab,
                    locale: locale,
                    onMarkPaid: markQuarterPaid
                )
            }
        }
    }

    private var footerActions: some View {
        VStack(spacing: BuxTokens.tight) {
            BuxButton(
                title: "My year summary",
                systemImage: "doc.richtext",
                role: .secondary,
                expands: true
            ) {
                showYearSummaryPreview = true
            }
            BuxButton(
                title: "Share year summary",
                systemImage: "square.and.arrow.up",
                role: .secondary,
                expands: true
            ) {
                exportYearPacket()
            }
            if display.isEnabled {
                NavigationLink {
                    TaxStudioHubView(initialTab: .calculator)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(appDataManager)
                        .environmentObject(studioStore)
                        .environmentObject(studioBrain)
                } label: {
                    Label {
                        BuxCatalogText.text("Full Tax Studio")
                    } icon: {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
        .padding(.bottom, BuxTokens.section)
    }

    private func markQuarterPaid() {
        let context = taxEnvelopeBrain.sourceContext()
        let quarterly = TaxEnvelopeEngine.quarterlyEstimate(context: context)
        let key = TaxEnvelopePaymentSchedule.periodKey(
            countryCode: context.countryCode,
            reference: context.now
        )
        studioStore.markTaxEnvelopePaymentPaid(periodKey: key, amount: quarterly.totalDue)
        taxEnvelopeBrain.refreshAll()
    }

    private func exportYearPacket() {
        let context = taxEnvelopeBrain.sourceContext()
        guard let data = TaxEnvelopeYearPacketExporter.generatePDF(context: context, display: display) else { return }
        yearPacketShare = BuxPDFSharePayload(data: data, fileName: "TaxYearSummary")
    }
}

// MARK: - Tabs

private struct TaxEnvelopeWeekTab: View {
    let display: TaxEnvelopeWeekDisplay
    let locale: Locale
    var onManualDeposit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    metric("You made this week", display.weekIncomeFormatted)
                    metric("Suggested set-aside", display.weekSetAsideTargetFormatted)
                    Text(BuxLocalizedString.format(
                        "Guide rate: %lld%%",
                        locale: locale,
                        display.weekSetAsideRatePercent
                    ))
                    .font(.system(size: 12, weight: .semibold))
                    Text(display.coachLine)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            BuxButton(
                title: "I set money aside",
                systemImage: "plus.circle.fill",
                role: .primary,
                expands: true,
                action: onManualDeposit
            )
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(BuxCatalogLabel.string(title, locale: locale))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold))
        }
    }
}

private struct TaxEnvelopeJarTab: View {
    let display: TaxEnvelopeJarDisplay
    let locale: Locale
    var onManualDeposit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            BuxButton(
                title: "I set money aside",
                systemImage: "plus.circle.fill",
                role: .primary,
                expands: true,
                action: onManualDeposit
            )

            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    HStack {
                        Text(BuxCatalogLabel.string("You've set aside", locale: locale))
                        Spacer()
                        Text(display.savedTotalFormatted)
                            .font(.system(size: 20, weight: .bold))
                    }
                    ProgressView(value: display.progressFraction)
                    HStack {
                        Text(BuxCatalogLabel.string("Estimated tax this year", locale: locale))
                        Spacer()
                        Text(display.targetFormatted)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(display.coachLine)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }

            if display.hasDeposits {
                BuxSectionHeader(title: "Recent set-asides")
                ForEach(display.recentDeposits) { row in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(row.amountFormatted)
                                .font(.system(size: 14, weight: .bold))
                            Text(row.dateLabel)
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                            if let note = row.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 11))
                                    .buxLabelSecondary()
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text(display.emptyStateLine)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TaxEnvelopeRemindersTab: View {
    let display: TaxEnvelopeRemindersDisplay
    let locale: Locale
    var onMarkPaid: () -> Void

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                metric("You've set aside", display.setAsideTotalFormatted)
                metric(display.dueAmountTitle, display.nextDueAmountFormatted, titleIsPrelocalized: true)
                metric(display.periodTitle, display.quarterLabel, titleIsPrelocalized: true)
                if let due = display.nextDueDateLabel {
                    metric("Due date", due)
                }
                metric("You pay tax", display.paymentScheduleLabel, titleIsPrelocalized: false)
                Text(display.coachLine)
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()

                if display.isCurrentPeriodPaid {
                    Label {
                        BuxCatalogText.text("Paid it")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.green)
                    .font(.system(size: 13, weight: .bold))
                } else {
                    BuxButton(
                        title: "Paid it",
                        systemImage: "checkmark.circle",
                        role: .primary,
                        expands: true,
                        action: onMarkPaid
                    )
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String, titleIsPrelocalized: Bool = false) -> some View {
        HStack {
            Text(titleIsPrelocalized ? title : BuxCatalogLabel.string(title, locale: locale))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
    }
}

private struct TaxEnvelopeYearSummaryPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain

    @State private var yearPacketShare: BuxPDFSharePayload?

    private var display: TaxEnvelopeRootDisplay { taxEnvelopeBrain.display }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    TaxEnvelopeYearPacketContentView(
                        context: taxEnvelopeBrain.sourceContext(),
                        display: display
                    )
                    .padding(BuxTokens.marginRegular)
                }
            }
            .buxCatalogNavigationTitle("My year summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exportPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .buxMeshSheetPresentation()
            .sheet(item: $yearPacketShare) { payload in
                BuxActivityShareSheet(items: payload.activityItems) {
                    yearPacketShare = nil
                }
                .buxShareSheetPresentation()
                .ignoresSafeArea()
            }
        }
    }

    private func exportPDF() {
        let context = taxEnvelopeBrain.sourceContext()
        guard let data = TaxEnvelopeYearPacketExporter.generatePDF(context: context, display: display) else { return }
        yearPacketShare = BuxPDFSharePayload(data: data, fileName: "TaxYearSummary")
    }
}
