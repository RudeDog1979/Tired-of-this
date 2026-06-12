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
                    Label("Open", systemImage: "arrow.forward.circle")
                }
            }

            Button(action: onSelect) {
                Label(
                    isSelected ? "Selected" : "Select",
                    systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                )
            }
            .disabled(isSelected)
        }
    }
}
