//
//  ExpenseNoteSheet.swift
//  BuxMuse
//
//  Quick note editor from swipe action.
//

import SwiftUI

struct ExpenseNoteSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let merchantName: String
    @Binding var notes: String
    let onSave: () throws -> Void

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Add note")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    .padding(.top, 24)

                Text(merchantName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                NotesField(notes: $notes)

                Button(action: {
                    try? onSave()
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(BuxMicroShrinkStyle())
                .padding(.horizontal, BuxLayout.marginHorizontal)

                Spacer()
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
        }
        .presentationDetents([.medium])
    }
}
