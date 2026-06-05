//
//  TaxPresetLocalizedViews.swift
//  BuxMuse
//
//  SwiftUI helpers that resolve translated tax preset copy at display time.
//

import SwiftUI

enum TaxPresetLocalizationSupport {
    static func taskKey(
        preset: TaxInfo,
        catalogUpdatedAt: String?,
        locale: Locale
    ) -> String {
        "\(catalogUpdatedAt ?? "")|\(preset.isoCode)|\(BuxStringCatalog.resourceTag(for: locale))"
    }

    @MainActor
    static func localized(
        _ preset: TaxInfo,
        catalogUpdatedAt: String?,
        interfaceLocale: Locale
    ) async -> TaxLocalizedPresetResult {
        await TaxPresetTranslator.localizedPreset(
            preset,
            catalogUpdatedAt: catalogUpdatedAt,
            interfaceLocale: interfaceLocale
        )
    }
}

struct TaxTranslationPackNoticeBanner: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @AppStorage(TaxTranslationUX.packNoticeDismissedKey) private var noticeDismissed = false

    var body: some View {
        if TaxTranslationUX.shouldShowPackNotice(interfaceLocale: appSettingsManager.interfaceLocale),
           !noticeDismissed {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 1)

                BuxCatalogDynamicText(
                    key: "BuxMuse can show tax rules in Spanish. iOS may ask to download a language pack once."
                )
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .multilineTextAlignment(.leading)

                Button {
                    TaxTranslationUX.dismissPackNotice()
                    noticeDismissed = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct TaxEnglishFallbackBadge: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        BuxCatalogDynamicText(key: "In English")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct TaxPresetLineSummaryText: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var taxManager = TaxManager.shared

    let preset: TaxInfo
    var font: Font = .system(size: 11, weight: .medium)
    var lineLimit: Int? = 2

    @State private var summary: String

    init(preset: TaxInfo, font: Font = .system(size: 11, weight: .medium), lineLimit: Int? = 2) {
        self.preset = preset
        self.font = font
        self.lineLimit = lineLimit
        _summary = State(initialValue: preset.presetLineSummary)
    }

    var body: some View {
        Text(summary)
            .font(font)
            .buxLabelSecondary()
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .task(id: taskKey) {
                let result = await TaxPresetLocalizationSupport.localized(
                    preset,
                    catalogUpdatedAt: taxManager.catalogUpdatedAt,
                    interfaceLocale: appSettingsManager.interfaceLocale
                )
                summary = result.preset.presetLineSummary
            }
    }

    private var taskKey: String {
        TaxPresetLocalizationSupport.taskKey(
            preset: preset,
            catalogUpdatedAt: taxManager.catalogUpdatedAt,
            locale: appSettingsManager.interfaceLocale
        )
    }
}
