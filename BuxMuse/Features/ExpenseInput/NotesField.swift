//
//  NotesField.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Native notes row — use inside Form Section.
//

import SwiftUI

struct NotesField: View {
    @Binding var notes: String

    var body: some View {
        TextField("Add a note...", text: $notes, axis: .vertical)
            .lineLimit(3...6)
    }
}
