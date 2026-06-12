//
//  TaxEnvelopeSetAsideSheet.swift
//  BuxMuse
//

import SwiftUI

struct TaxEnvelopeSetAsideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    let entryId: UUID
    let incomeAmount: Decimal

    @State private var markedSaved = false

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var setAside: TaxEnvelopeSetAsideResult {
        TaxEnvelopeEngine.setAsideForIncome(
            grossIncome: incomeAmount,
            context: taxEnvelopeBrain.sourceContext()
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                VStack(spacing: BuxTokens.block) {
                    BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                        VStack(spacing: BuxTokens.tight) {
                            BuxCatalogText.text("Set aside for tax")
                                .font(.system(size: 13, weight: .semibold))
                                .buxLabelSecondary()
                            Text(appSettingsManager.format(setAside.amount))
                                .font(.system(size: 36, weight: .bold))
                            Text(BuxLocalizedString.format(
                                "Guide: %lld%% from BuxMuse Intelligence",
                                locale: locale,
                                Int(truncating: (setAside.rateFraction * 100) as NSDecimalNumber)
                            ))
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    BuxButton(
                        title: markedSaved ? "Added to set-aside total" : "Add to my set-aside total",
                        systemImage: markedSaved ? "checkmark.circle.fill" : "plus.circle.fill",
                        role: .primary,
                        expands: true
                    ) {
                        saveToJar()
                    }
                    .disabled(markedSaved)

                    BuxButton(title: "Skip", role: .secondary, expands: true) {
                        dismiss()
                    }
                }
                .padding(BuxTokens.marginRegular)
            }
            .buxCatalogNavigationTitle("Set aside")
            .buxInterfaceLocale()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
        }
    }

    private func saveToJar() {
        studioStore.addTaxEnvelopeDeposit(
            amount: setAside.amount,
            linkedEntryId: entryId
        )
        simpleStudioStore.markEntryTaxSetAside(
            entryId: entryId,
            amount: setAside.amount,
            saved: true
        )
        markedSaved = true
        BuxSaveFeedback.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }
}
