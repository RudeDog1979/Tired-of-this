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
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
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
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
            )
        }
    }
}
