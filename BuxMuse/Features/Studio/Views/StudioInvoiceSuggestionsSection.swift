//
//  StudioInvoiceSuggestionsSection.swift
//  BuxMuse
//
//  Shared invoice suggestion cards for Pro + Simple hubs and detail screens.
//

import SwiftUI

struct StudioProInvoiceSuggestionsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let suggestions: [StudioInvoiceSuggestion]
    var onSelect: (StudioInvoiceSuggestion) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogDynamicText(key: "INVOICE SUGGESTIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .kerning(1)

                BuxCatalogDynamicText(key: "From billable hours, new time, and project expenses.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                ForEach(suggestions.prefix(5)) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        proSuggestionRow(suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func proSuggestionRow(_ suggestion: StudioInvoiceSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(suggestion.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(appSettingsManager.format(suggestion.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(themeManager.labelTertiary(for: colorScheme))
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 16)
    }
}

struct SimpleStudioInvoiceSuggestionsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let suggestions: [SimpleInvoiceSuggestion]
    var onSelect: (SimpleInvoiceSuggestion) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogDynamicText(key: "READY TO INVOICE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .kerning(1)

                BuxCatalogDynamicText(key: "Jobs where money is still waiting — tap to send a simple invoice.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                ForEach(suggestions.prefix(5)) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        simpleSuggestionRow(suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func simpleSuggestionRow(_ suggestion: SimpleInvoiceSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if suggestion.customerName.isEmpty {
                        BuxCatalogDynamicText(key: "Customer")
                    } else {
                        Text(suggestion.customerName)
                    }
                }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(suggestion.jobDescription)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(suggestion.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
            Spacer(minLength: 8)
            Text(appSettingsManager.format(suggestion.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 16)
    }
}
