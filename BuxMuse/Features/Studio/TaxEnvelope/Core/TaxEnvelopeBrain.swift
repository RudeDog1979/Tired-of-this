//
//  TaxEnvelopeBrain.swift
//  BuxMuse
//

import Foundation
import Combine

@MainActor
public final class TaxEnvelopeBrain: ObservableObject {
    @Published private(set) var display: TaxEnvelopeRootDisplay = .empty

    private let studioStore: StudioStore
    private let simpleStore: SimpleStudioStore
    private let settings: SettingsStore
    private let appSettings: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()

    init(
        studioStore: StudioStore,
        simpleStore: SimpleStudioStore,
        settings: SettingsStore,
        appSettings: AppSettingsManager
    ) {
        self.studioStore = studioStore
        self.simpleStore = simpleStore
        self.settings = settings
        self.appSettings = appSettings
        wireRefreshTriggers()
        refreshAll()
    }

    func refreshAll() {
        guard settings.studioEnabled else {
            display = .empty
            return
        }
        let context = sourceContext()
        let format: (Decimal) -> String = { [appSettings] in appSettings.format($0) }
        let locale = appSettings.interfaceLocale
        display = TaxEnvelopeEngine.buildRootDisplay(
            context: context,
            format: format,
            locale: locale
        )
    }

    func sourceContext(now: Date = Date()) -> TaxEnvelopeSourceContext {
        TaxEnvelopeSourceContext(
            profile: studioStore.profile,
            taxProfile: studioStore.taxProfile,
            proInvoices: studioStore.invoices,
            proReceipts: studioStore.receipts,
            mileageEntries: studioStore.mileageEntries,
            simpleEntries: simpleStore.entries,
            envelope: studioStore.taxEnvelope,
            mileageRatePerUnit: settings.mileageRatePerUnit,
            locale: appSettings.interfaceLocale,
            now: now,
            appRegionCountryCode: appSettings.selectedCountry.id
        )
    }

    private func wireRefreshTriggers() {
        Publishers.MergeMany(
            studioStore.$taxEnvelope.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$taxProfile.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$invoices.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$receipts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$mileageEntries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            simpleStore.$entries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$studioEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            appSettings.$selectedCountry.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.refreshAll() }
        .store(in: &cancellables)
    }
}

// MARK: - Display assembly

extension TaxEnvelopeEngine {

    static func buildRootDisplay(
        context: TaxEnvelopeSourceContext,
        format: (Decimal) -> String,
        locale: Locale
    ) -> TaxEnvelopeRootDisplay {
        let envelope = context.envelope
        let country = CountryDisplayL10n.displayName(isoCode: context.countryCode, locale: locale)
        let (rate, _, taxYear, rulesAsOf) = resolveSaveRate(context: context)
        let ratePercent = Int(truncating: (rate * 100) as NSDecimalNumber)

        let weekIncome = TaxEnvelopeContextBridge.weekIncomeTotal(
            entries: context.simpleEntries,
            reference: context.now
        )
        let weekTarget = weekIncome * rate

        let jarSaved = jarSavedTotal(envelope: envelope)
        let jarTarget = fiscalYearSetAsideTarget(context: context)
        let progress = jarTarget > 0
            ? min(1, Double(truncating: (jarSaved / jarTarget) as NSDecimalNumber))
            : 0

        let quarterly = quarterlyEstimate(context: context)
        let schedule = context.taxProfile.paymentSchedule
        let periodKey = TaxEnvelopePaymentSchedule.periodKey(
            countryCode: context.countryCode,
            reference: context.now
        )
        let isPaid = envelope.paymentMarks.contains { $0.periodKey == periodKey }
        let periodValue: String = {
            switch schedule.lowercased() {
            case "annually", "annual", "yearly":
                return taxYear ?? BuxCatalogLabel.string("This year", locale: locale)
            case "monthly":
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: context.now)
            default:
                return quarterly.quarterLabel
            }
        }()

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateStyle = .medium

        let deposits = envelope.deposits
            .sorted { $0.savedAt > $1.savedAt }
            .prefix(8)
            .map { deposit in
                TaxEnvelopeDepositRow(
                    id: deposit.id,
                    amountFormatted: format(deposit.amount),
                    dateLabel: dateFormatter.string(from: deposit.savedAt),
                    note: deposit.note
                )
            }

        let hubHero = buildHubHeroDisplay(
            weekTarget: weekTarget,
            jarSaved: jarSaved,
            jarTarget: jarTarget,
            envelope: envelope,
            format: format,
            locale: locale
        )

        return TaxEnvelopeRootDisplay(
            isEnabled: envelope.isEnabled,
            needsOnboarding: !envelope.onboardingCompleted,
            hubHero: hubHero,
            weekTab: TaxEnvelopeWeekDisplay(
                weekIncomeFormatted: format(weekIncome),
                weekSetAsideTargetFormatted: format(weekTarget),
                weekSetAsideRatePercent: ratePercent,
                coachLine: taxTileCoachLine(context: context, persona: .other, locale: locale),
                incomeEntryCount: context.simpleEntries.filter {
                    Calendar.current.isDate($0.createdAt, equalTo: context.now, toGranularity: .weekOfYear)
                        && TaxEnvelopeContextBridge.incomeAmount(for: $0) > 0
                }.count
            ),
            jarTab: TaxEnvelopeJarDisplay(
                savedTotalFormatted: format(jarSaved),
                targetFormatted: format(jarTarget),
                progressFraction: progress,
                recentDeposits: Array(deposits),
                coachLine: BuxCatalogLabel.string(
                    "Tracks what you log as set aside for tax. BuxMuse does not hold your money.",
                    locale: locale
                ),
                emptyStateLine: BuxCatalogLabel.string(
                    "No set-asides logged yet. Log pay and tap Add, or use I set money aside.",
                    locale: locale
                ),
                hasDeposits: !envelope.deposits.isEmpty
            ),
            remindersTab: TaxEnvelopeRemindersDisplay(
                nextDueDateLabel: quarterly.nextPaymentDate.map { dateFormatter.string(from: $0) },
                nextDueAmountFormatted: format(quarterly.totalDue),
                setAsideTotalFormatted: format(jarSaved),
                quarterLabel: periodValue,
                dueAmountTitle: TaxEnvelopePaymentSchedule.dueAmountTitle(schedule: schedule, locale: locale),
                periodTitle: TaxEnvelopePaymentSchedule.periodTitle(schedule: schedule, locale: locale),
                isCurrentPeriodPaid: isPaid,
                paymentScheduleLabel: TaxEnvelopePaymentSchedule.localizedScheduleName(schedule, locale: locale),
                coachLine: BuxCatalogLabel.string(
                    "Estimated from your books and BuxMuse Intelligence on your device. Change schedule below if yours is different.",
                    locale: locale
                )
            ),
            countryLabel: country,
            taxYearLabel: taxYear.map { BuxLocalizedString.format("Tax year %@", locale: locale, $0) },
            rulesAsOfLabel: rulesAsOf.map {
                BuxLocalizedString.format("Intelligence updated %@", locale: locale, $0)
            }
        )
    }

    static func buildHubHeroDisplay(
        weekTarget: Decimal,
        jarSaved: Decimal,
        jarTarget: Decimal,
        envelope: TaxEnvelopeState,
        format: (Decimal) -> String,
        locale: Locale
    ) -> TaxSavingsHubHeroDisplay {
        let weekLine: String
        if weekTarget > 0 {
            weekLine = BuxLocalizedString.format(
                "Set aside %@ from this week's pay",
                locale: locale,
                format(weekTarget)
            )
        } else {
            weekLine = BuxCatalogLabel.string(
                "Log pay this week to see how much to set aside",
                locale: locale
            )
        }

        let yearLine: String
        if jarTarget > 0 {
            yearLine = BuxLocalizedString.format(
                "%@ of ~%@ estimated tax this year",
                locale: locale,
                format(jarSaved),
                format(jarTarget)
            )
        } else if jarSaved > 0 {
            yearLine = BuxLocalizedString.format(
                "%@ set aside — log pay to refresh your estimate",
                locale: locale,
                format(jarSaved)
            )
        } else {
            yearLine = BuxCatalogLabel.string(
                "Log pay to see estimated tax for the year",
                locale: locale
            )
        }

        return TaxSavingsHubHeroDisplay(
            weekSetAsideLine: weekLine,
            yearProgressLine: yearLine,
            isEnabled: envelope.isEnabled && envelope.onboardingCompleted,
            needsSetup: !envelope.onboardingCompleted,
            disclaimer: BuxCatalogLabel.string(
                "Tracks set-asides you log. BuxMuse is not a bank.",
                locale: locale
            )
        )
    }
}
