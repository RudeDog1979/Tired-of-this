//
//  TaxEnvelopeOnboardingView.swift
//  BuxMuse
//

import SwiftUI

struct TaxEnvelopeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var studioStore: StudioStore

    var onFinish: (Bool) -> Void

    @State private var step = 0
    @State private var isSelfEmployed = true
    @State private var payFrequency = "weekly"
    @State private var paymentSchedule = "quarterly"
    @State private var saveRatePercent = 20

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var countryDisplayName: String {
        let code = taxEnvelopeBrain.sourceContext().countryCode
        return CountryDisplayL10n.displayName(isoCode: code, locale: locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    progress
                    ScrollView(showsIndicators: false) {
                        stepContent
                    }
                    actions
                }
                .padding(BuxTokens.marginRegular)
            }
            .buxCatalogNavigationTitle("Tax savings")
            .buxInterfaceLocale()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { onFinish(false); dismiss() }
                }
            }
            .onAppear {
                let rec = TaxEnvelopeEngine.onboardingRecommendation(context: taxEnvelopeBrain.sourceContext())
                saveRatePercent = max(5, rec.saveRatePercent)
                paymentSchedule = normalizedSchedule(rec.paymentSchedule)
            }
        }
    }

    private var progress: some View {
        ProgressView(value: Double(step + 1), total: 4)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            onboardingCard(
                title: "You get paid on your own",
                message: "BuxMuse Intelligence uses tax rules for the country in your app settings — on your device."
            ) {
                Toggle(isOn: $isSelfEmployed) {
                    BuxCatalogText.text("I earn money on my own")
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            }
        case 1:
            onboardingCard(
                title: "We suggest how much to set aside",
                message: "Based on what you log and BuxMuse Intelligence for your country — kept on your device."
            ) {
                Picker("", selection: $payFrequency) {
                    Text(BuxCatalogLabel.string("Weekly", locale: locale)).tag("weekly")
                    Text(BuxCatalogLabel.string("Monthly", locale: locale)).tag("monthly")
                    Text(BuxCatalogLabel.string("Per job", locale: locale)).tag("perJob")
                }
                .buxThemedSegmentedPicker()
            }
        case 2:
            onboardingCard(
                title: "You log what you set aside",
                message: "After logging pay, tap Add — or use I set money aside anytime. BuxMuse tracks the total; it does not hold your money."
            ) {
                Text(countryDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .buxLabelSecondary()
            }
        default:
            let recommendation = TaxEnvelopeEngine.onboardingRecommendation(
                context: taxEnvelopeBrain.sourceContext()
            )
            onboardingCard(
                title: "We remind you before tax is due",
                message: BuxLocalizedString.format(
                    "Due dates and amounts from your books and BuxMuse Intelligence for %@.",
                    locale: locale,
                    countryDisplayName
                ),
                messageIsPrelocalized: true
            ) {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    BuxCatalogText.text("When do you pay tax?")
                        .font(.system(size: 13, weight: .bold))
                    Picker("", selection: $paymentSchedule) {
                        ForEach(TaxEnvelopePaymentSchedule.userSelectableSchedules, id: \.self) { schedule in
                            Text(TaxEnvelopePaymentSchedule.localizedScheduleName(schedule, locale: locale))
                                .tag(schedule)
                        }
                    }
                    .buxThemedSegmentedPicker()
                    Text(
                        BuxLocalizedString.format(
                            "Typical in %@: %@. Pick what matches you.",
                            locale: locale,
                            countryDisplayName,
                            TaxEnvelopePaymentSchedule.localizedScheduleName(
                                normalizedSchedule(recommendation.paymentSchedule),
                                locale: locale
                            )
                        )
                    )
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                    saveRateGuideSection
                    Text(recommendation.coachLine)
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
            }
        }
    }

    private func normalizedSchedule(_ value: String) -> String {
        switch value.lowercased() {
        case "monthly": return "monthly"
        case "annually", "annual", "yearly": return "annually"
        default: return "quarterly"
        }
    }

    private var saveRateGuideSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxCatalogText.text("Default set-aside guide")
                .font(.system(size: 13, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 12) {
                Text(BuxLocalizedString.format("%lld%%", locale: locale, saveRatePercent))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Stepper("", value: $saveRatePercent, in: 5...50, step: 1)
                    .labelsHidden()
            }
        }
    }

    private var actions: some View {
        HStack(spacing: BuxTokens.tight) {
            if step > 0 {
                BuxButton(title: "Back", role: .secondary, expands: false) {
                    step -= 1
                }
            }
            BuxButton(
                title: step == 3 ? "Start tax savings" : "Next",
                systemImage: step == 3 ? "checkmark" : "arrow.right",
                role: .primary,
                expands: true
            ) {
                if step < 3 {
                    step += 1
                } else {
                    finishOnboarding()
                }
            }
        }
    }

    private func onboardingCard<Content: View>(
        title: String,
        message: String,
        messageIsPrelocalized: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                Text(BuxCatalogLabel.string(title, locale: locale))
                    .font(.system(size: 20, weight: .bold))
                Text(
                    messageIsPrelocalized
                        ? message
                        : BuxCatalogLabel.string(message, locale: locale)
                )
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                content()
            }
        }
    }

    private func finishOnboarding() {
        var taxProfile = studioStore.taxProfile
        if isSelfEmployed {
            taxProfile.taxIncomeType = .selfEmployed
        }
        let countryCode = taxEnvelopeBrain.sourceContext().countryCode
        TaxCatalogProfileHydrator.applyCatalogRules(
            to: &taxProfile,
            countryCode: countryCode,
            regionCode: taxProfile.regionCode
        )
        taxProfile.countryCode = countryCode
        taxProfile.paymentSchedule = paymentSchedule
        studioStore.updateTaxProfile(taxProfile)

        var envelope = studioStore.taxEnvelope
        envelope.isEnabled = true
        envelope.onboardingCompleted = true
        envelope.recommendedSaveRateOverride = Decimal(saveRatePercent) / 100
        studioStore.updateTaxEnvelope(envelope)

        onFinish(true)
        dismiss()
    }
}
