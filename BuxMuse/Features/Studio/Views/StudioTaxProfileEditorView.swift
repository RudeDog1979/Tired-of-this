//
//  StudioTaxProfileEditorView.swift
//  BuxMuse
//
//  Legacy entry point — unified Tax Profile lives in StudioTaxReferenceView.
//

import SwiftUI

struct StudioTaxProfileEditorView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        StudioTaxReferenceView()
            .environmentObject(themeManager)
    }
}
