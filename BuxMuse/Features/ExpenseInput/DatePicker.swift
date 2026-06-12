//
//  DatePicker.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Native transaction date row — use inside Form Section.
//

import SwiftUI

struct DateFieldPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Binding var date: Date

    var body: some View {
        DatePicker(BuxCatalogLabel.string("Transaction date", locale: appSettingsManager.interfaceLocale), selection: $date, displayedComponents: .date)
            .tint(themeManager.contrastAccentColor(for: colorScheme))
    }
}
