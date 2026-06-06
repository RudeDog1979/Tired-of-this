//
//  DatePicker.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Native transaction date row — use inside Form Section.
//

import SwiftUI

struct DateFieldPicker: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Binding var date: Date

    var body: some View {
        DatePicker(BuxCatalogLabel.string("Transaction date", locale: appSettingsManager.interfaceLocale), selection: $date, displayedComponents: .date)
            .tint(themeManager.current.accentColor)
    }
}
