//
//  ScopeCreepRadarSettingsView.swift
//  BuxMuse
//
//  Pro Studio — scope budget tracking for client projects.
//

import SwiftUI

struct ScopeCreepRadarSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            ProFeatureHeader(
                title: "Scope creep radar",
                subtitle: "Monitor hours and revision budgets on Studio projects. Get in-app alerts and ready-to-send scope change notices.",
                systemImage: "scope",
                tint: .red
            )

            BuxFormSection(title: "Status") {
                Toggle(isOn: $store.antiScopeCreepEnabled.animation(.spring(response: 0.3, dampingFraction: 0.75))) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Enable scope radar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Shows scope status on Pro Studio projects with budgeted hours and revision limits.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.red)
                .buxFormFieldPadding()
            }

            if store.antiScopeCreepEnabled {
                BuxFormSection(title: "How it works") {
                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(icon: "clock.badge.checkmark", color: .orange, title: "Hours budget", body: "Set budgeted hours on each Studio project. Logged time entries count toward the cap.")
                        Divider().opacity(0.1)
                        infoRow(icon: "arrow.triangle.2.circlepath", color: .blue, title: "Revision slots", body: "Track included revisions vs. used count. Over-limit triggers a risk alert.")
                        Divider().opacity(0.1)
                        infoRow(icon: "envelope.fill", color: .purple, title: "Scope email template", body: "Generate a professional scope-change email from the project detail when you're over budget.")
                    }
                    .buxFormFieldPadding()
                }
            }
        }
        .buxCatalogNavigationTitle("Scope creep radar")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.antiScopeCreepEnabled) { _, _ in store.save() }
    }

    private func infoRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                BuxCatalogText.text(title)
                    .font(.system(size: 13, weight: .bold))
                BuxCatalogText.text(body)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
