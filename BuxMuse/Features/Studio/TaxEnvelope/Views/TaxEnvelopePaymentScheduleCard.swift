//
//  TaxEnvelopePaymentScheduleCard.swift
//  BuxMuse
//

import SwiftUI

struct TaxEnvelopePaymentScheduleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let selection: String
    let catalogDefault: String?
    var onSelect: (String) -> Void

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogText.text("When do you pay tax?")
                    .font(.system(size: 13, weight: .bold))

                Picker("", selection: Binding(
                    get: { normalized(selection) },
                    set: { onSelect($0) }
                )) {
                    ForEach(TaxEnvelopePaymentSchedule.userSelectableSchedules, id: \.self) { schedule in
                        Text(TaxEnvelopePaymentSchedule.localizedScheduleName(schedule, locale: locale))
                            .tag(schedule)
                    }
                }
                .buxThemedSegmentedPicker()

                if let catalogDefault {
                    Text(
                        BuxLocalizedString.format(
                            "BuxMuse Intelligence suggests %@ for your country. Pick what matches you — estimates update right away.",
                            locale: locale,
                            TaxEnvelopePaymentSchedule.localizedScheduleName(catalogDefault, locale: locale)
                        )
                    )
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    BuxCatalogText.text("Pick what matches you — due dates and reminders update right away.")
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func normalized(_ value: String) -> String {
        switch value.lowercased() {
        case "monthly": return "monthly"
        case "annually", "annual", "yearly": return "annually"
        default: return "quarterly"
        }
    }
}
