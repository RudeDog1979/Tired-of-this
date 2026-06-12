//
//  BuxPadRegularShell.swift
//  BuxMuse — iPad regular width: sidebar navigation via sidebarAdaptable.
//

import SwiftUI

struct BuxPadRegularShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .buxPadSidebarAdaptableTabStyle()
    }
}
