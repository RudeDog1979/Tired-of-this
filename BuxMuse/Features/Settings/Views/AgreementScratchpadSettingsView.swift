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
                title: "Agreement Scratchpad",
                subtitle: "Draft scope bullets, deliverables, and sign-off notes for clients — stored locally on your device.",
                systemImage: "doc.text.fill",
                tint: Color(hex: "#5856D6")
            )

            BuxFormSection(title: "Status") {
                Toggle(isOn: $store.agreementScratchpadEnabled.animation(.spring(response: 0.3, dampingFraction: 0.75))) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable Agreement Scratchpad")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Unlocks agreement drafts linked to Studio clients and projects.")
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
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Open agreement drafts")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Create, edit, and share scope agreements with clients.")
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
                        infoRow(icon: "signature", color: .green, title: "Sign-off line", body: "Record client name and date when they approve — for your records, not e-sign.")
                        Divider().opacity(0.1)
                        infoRow(icon: "square.and.arrow.up", color: .blue, title: "Share as text", body: "Send agreement text via Messages, WhatsApp, or email from Studio.")
                    }
                    .buxFormFieldPadding()
                }
            }
        }
        .navigationTitle("Agreement Scratchpad")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.agreementScratchpadEnabled) { _, _ in store.save() }
    }

    private func infoRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
