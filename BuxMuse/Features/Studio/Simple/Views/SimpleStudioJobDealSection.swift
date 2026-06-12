//
//  SimpleStudioJobDealSection.swift
//  BuxMuse
//
//  Simple Studio job price + quote — no Pro agreement scratchpad.
//

import SwiftUI

struct SimpleStudioJobDealSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let job: SimpleStudioEntry
    var onSendQuote: () -> Void

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogText.text("Price & quote")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()

                if let agreed = job.agreedPrice, agreed > 0 {
                    HStack {
                        BuxCatalogText.text("Agreed price")
                        Spacer()
                        Text(appSettingsManager.format(agreed))
                            .font(.system(size: 16, weight: .bold))
                    }
                } else {
                    BuxCatalogText.text("No price on this job yet.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                }

                if let label = job.jobLabel, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                }

                BuxButton(
                    title: "Send quote",
                    systemImage: "doc.text.fill",
                    role: .secondary,
                    expands: true,
                    action: onSendQuote
                )
            }
        }
    }
}

struct SimpleStudioQuoteReminderBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
