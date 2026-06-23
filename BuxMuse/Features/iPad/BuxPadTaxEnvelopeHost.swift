//
//  BuxPadTaxEnvelopeHost.swift
//  BuxMuse — iPad Tax Envelope tool host.
//

import SwiftUI

struct BuxPadTaxEnvelopeHost: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @State private var selectedTab: TaxEnvelopeTab = .week

    var body: some View {
        Group {
            if layoutMode == .regular {
                BuxPadSplitScaffold {
                    taxEnvelopeSidebar
                } detail: {
                    TaxEnvelopeRootView()
                }
            } else {
                TaxEnvelopeRootView()
            }
        }
    }

    private var taxEnvelopeSidebar: some View {
        List {
            ForEach(TaxEnvelopeTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack {
                        Text(tab.label(locale: BuxInterfaceLocale.currentInterfaceLocale))
                        Spacer(minLength: 0)
                        if selectedTab == tab {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .buxPadHoverable()
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(BuxLocalizedString.string("Tax Envelope", locale: BuxInterfaceLocale.currentInterfaceLocale))
    }
}
