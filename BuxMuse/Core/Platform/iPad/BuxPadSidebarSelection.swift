//
//  BuxPadSidebarSelection.swift
//  BuxMuse — iPad sidebar row selection chrome (Settings-style pill).
//

import SwiftUI

enum BuxPadSidebarSelection {
    static let rowInsets = EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)

    static var selectionAnimation: Animation {
        BuxMotion.slide
    }

    static func select<T: Equatable>(_ value: T, into binding: Binding<T?>) {
        withAnimation(selectionAnimation) {
            binding.wrappedValue = value
        }
    }

    static func rowBackground(
        isSelected: Bool,
        themeManager: ThemeManager,
        colorScheme: ColorScheme
    ) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(themeManager.contrastAccentColor(for: colorScheme).opacity(isSelected ? 0.12 : 0))
            .scaleEffect(isSelected ? 1 : 0.94, anchor: .center)
            .animation(selectionAnimation, value: isSelected)
    }
}
