//
//  AgreementScratchpadSettingsView.swift
//  BuxMuse
//
//  Pro Studio — lightweight client agreement drafts.
//

import SwiftUI

struct AgreementScratchpadSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioStore: StudioStore
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            ProFeatureHeader(
                title: "Agreement scratchpad",
                subtitle: "Draft scope bullets, deliverables, and sign-off notes for clients — stored locally on your device.",
                systemImage: "doc.text.fill",
                tint: Color(hex: "#5856D6")
            )

            BuxFormSection(title: "Status") {
                Toggle(isOn: $store.agreementScratchpadEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Enable agreement scratchpad")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Unlocks agreement drafts linked to Studio clients and projects.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color(hex: "#5856D6"))
                .buxFormFieldPadding()
            }

            if store.agreementScratchpadEnabled {
                BuxFormSection(title: "Drafts") {
                    NavigationLink {
                        AgreementScratchpadListView()
                            .environmentObject(studioStore)
                            .environmentObject(SimpleStudioStore.shared)
                            .environmentObject(themeManager)
                            .environment(\.isSettingsContext, true)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                BuxCatalogDynamicText(key: "Open agreement drafts")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Create, edit, and share scope agreements with clients.")
                                    .font(.system(size: 12, weight: .medium))
                                    .buxLabelSecondary()
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .buxLabelSecondary()
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormRowDivider()
                    NavigationLink {
                        StudioAgreementDefaultTermsSettingsView()
                            .environmentObject(themeManager)
                            .environment(\.isSettingsContext, true)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                BuxCatalogDynamicText(key: "Default terms & conditions")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Pre-made clauses for new agreements — deposits, cancellations, liability, and more.")
                                    .font(.system(size: 12, weight: .medium))
                                    .buxLabelSecondary()
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .buxLabelSecondary()
                        }
                        .buxFormFieldPadding()
                    }
                    BuxFormRowDivider()
                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(icon: "list.bullet.rectangle", color: .indigo, title: "Scope & deliverables", body: "Capture what you're delivering and what's out of scope before work starts.")
                        Divider().opacity(0.1)
                        infoRow(icon: "doc.plaintext", color: .purple, title: "Terms & conditions", body: "Pick editable template clauses or write your own — included in PDFs.")
                        Divider().opacity(0.1)
                        infoRow(icon: "signature", color: .green, title: "Client approval", body: "In person, clear to go, attach a signed PDF, or note an external service — stored on your device.")
                        Divider().opacity(0.1)
                        infoRow(icon: "square.and.arrow.up", color: .blue, title: "Share & attach", body: "Export PDF, mark terms sent, and attach what the client signed and returned.")
                    }
                    .buxFormFieldPadding()
                }
                .transaction { $0.animation = nil }
            }
        }
        .buxCatalogNavigationTitle("Agreement scratchpad")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
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
