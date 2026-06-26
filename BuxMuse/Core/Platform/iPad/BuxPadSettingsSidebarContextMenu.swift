//
//  BuxPadSettingsSidebarContextMenu.swift
//  BuxMuse — iPad settings sidebar row context menu (trackpad / right-click).
//

import SwiftUI

extension View {
    func buxPadSettingsSidebarContextMenu(
        destination: SettingsDestinationType,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        modifier(BuxPadSettingsSidebarContextMenuModifier(
            destination: destination,
            isSelected: isSelected,
            onSelect: onSelect
        ))
    }
}

private struct BuxPadSettingsSidebarContextMenuModifier: ViewModifier {
    let destination: SettingsDestinationType
    let isSelected: Bool
    let onSelect: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            if !isSelected {
                Button(action: onSelect) {
                    Label(BuxCatalogLabel.string("Open", locale: BuxInterfaceLocale.currentInterfaceLocale), systemImage: "arrow.forward.circle")
                }
            }

            Button(action: onSelect) {
                Label(
                    isSelected
                        ? BuxCatalogLabel.string("Selected", locale: BuxInterfaceLocale.currentInterfaceLocale)
                        : BuxCatalogLabel.string("Select", locale: BuxInterfaceLocale.currentInterfaceLocale),
                    systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                )
            }
            .disabled(isSelected)
        }
    }
}
