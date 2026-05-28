//
//  CategoryPicker.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Horizontal category selector with custom-pill animations matching BuxMuse design system.
//

import SwiftUI

struct CategoryPicker: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedCategory: TransactionCategory
    @Namespace private var pillNamespace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                .kerning(1.2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TransactionCategory.allCases) { cat in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                selectedCategory = cat
                            }
                        }) {
                            Text(cat.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedCategory == cat ? themeManager.current.accentColor : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    ZStack {
                                        if selectedCategory == cat {
                                            Capsule()
                                                .fill(themeManager.current.accentColor.opacity(0.12))
                                                .matchedGeometryEffect(id: "active_pill", in: pillNamespace)
                                        } else {
                                            Capsule()
                                                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                                        }
                                    }
                                )
                        }
                        .buttonStyle(MorphingPillButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
            .buxHorizontalScrollEdgeFade(background: themeManager.screenBackground(for: colorScheme))
        }
    }
}
