//
//  BuxPadExpenseUndoOverlay.swift
//  BuxMuse — Root-level undo toast above iPad split chrome.
//

import SwiftUI

struct BuxPadExpenseUndoOverlay: View {
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ExpenseUndoToastView()
            .environmentObject(themeManager)
            .environmentObject(brain)
            .zIndex(1100)
    }
}
