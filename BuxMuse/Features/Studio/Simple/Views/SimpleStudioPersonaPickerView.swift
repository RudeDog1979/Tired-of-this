//
//  SimpleStudioPersonaPickerView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioPersonaPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settings = SettingsStore.shared

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxTokens.block) {
                        VStack(alignment: .leading, spacing: 8) {
                            BuxCatalogDynamicText(key: "What kind of work do you do?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            BuxCatalogDynamicText(key: "Same app for everyone — this just sets smart defaults. Change anytime in Settings.")
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                        }
                        .padding(.top, BuxTokens.section)

                        VStack(spacing: BuxTokens.tight) {
                            ForEach(StudioPersona.allCases) { persona in
                                personaRow(persona)
                            }
                        }
                    }
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.bottom, BuxTokens.block)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .buxInterfaceLocale()
        }
    }

    private func personaRow(_ persona: StudioPersona) -> some View {
        BuxCardButton {
            settings.studioPersona = persona
            settings.studioPersonaConfigured = true
            settings.studioMode = .simple
            settings.save()
            onComplete()
        } label: {
            HStack(spacing: BuxTokens.section) {
                ZStack {
                    RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                        .fill(themeManager.accentWash(for: colorScheme))
                        .frame(width: 44, height: 44)
                    Image(systemName: persona.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(persona.localizedTitle(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(persona.localizedSubtitle(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme).opacity(0.5))
            }
            .padding(BuxTokens.section)
            .contentShape(Rectangle())
        }
    }
}
