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
    @Binding var date: Date

    var body: some View {
        DatePicker("Transaction Date", selection: $date, displayedComponents: .date)
            .tint(themeManager.current.accentColor)
    }
}
