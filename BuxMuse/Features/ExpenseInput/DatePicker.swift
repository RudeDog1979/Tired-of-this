//
//  DatePicker.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Transaction date selector with solid card row styling conforming to the design guidelines.
//

import SwiftUI

struct DateFieldPicker: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var date: Date
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                .kerning(1.2)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.current.accentColor)
                    .font(.system(size: 16, weight: .semibold))
                
                DatePicker("Transaction Date", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(themeManager.current.accentColor)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .expensesThemedCardChrome(cornerRadius: 16)
        }
    }
}
