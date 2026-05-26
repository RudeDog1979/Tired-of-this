//
//  MerchantAutocompleteView.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Autocompletion dropdown list showing merchant options in solid BuxMuse style cards.
//

import SwiftUI

struct MerchantAutocompleteView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { onSelect(suggestion) }) {
                            HStack(spacing: 12) {
                                AsyncMerchantLogoView(merchantName: suggestion, size: 32)
                                
                                Text(suggestion)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(BuxMicroShrinkStyle())
                        
                        Divider().opacity(0.08)
                    }
                }
            }
        }
        .frame(maxHeight: 180)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, x: 0, y: 5)
    }
}
