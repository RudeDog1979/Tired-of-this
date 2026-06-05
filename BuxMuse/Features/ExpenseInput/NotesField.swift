//
//  NotesField.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Native notes row — use inside Form Section.
//

import SwiftUI

struct NotesField: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Binding var notes: String

    var body: some View {
        TextField(BuxCatalogLabel.string("Add a note...", locale: appSettingsManager.interfaceLocale), text: $notes, axis: .vertical)
            .lineLimit(3...6)
    }
}
