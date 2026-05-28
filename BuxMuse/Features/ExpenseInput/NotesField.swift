//
//  NotesField.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Add a brief optional description text field formatted as a solid card row.
//

import SwiftUI

struct NotesField: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var notes: String
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES (OPTIONAL)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                .kerning(1.2)
            
            TextField("Add a note...", text: $notes)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .tint(themeManager.current.accentColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .expensesThemedCardChrome(cornerRadius: 16)
        }
    }
}
