//
//  ExpandableExpenseCard.swift
//  BuxMuse
//

import SwiftUI

struct ExpandableExpenseCard: View {
    let expense: ExpenseRowDisplay
    let namespace: Namespace.ID
    
    @Binding var expandedId: UUID?
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    private var isExpanded: Bool {
        expandedId == expense.id
    }
    
    private var cardColor: Color {
        themeManager.cardFill(for: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Always visible
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.name)
                        .font(.system(size: 16, weight: .bold))
                        .matchedGeometryEffect(id: "name_\(expense.id)", in: namespace)
                    
                    if let category = expense.category {
                        Text(category)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .matchedGeometryEffect(id: "category_\(expense.id)", in: namespace)
                    }
                }
                
                Spacer()
                
                Text(expense.amountFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .matchedGeometryEffect(id: "amount_\(expense.id)", in: namespace)
                
                Button {
                    withAnimation(.buxLiquidSpring) {
                        if isExpanded {
                            expandedId = nil
                        } else {
                            expandedId = expense.id
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.current.accentColor.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    if let heatZone = expense.heatZone {
                        insightRow(icon: "flame.fill", title: "Heat Zone", value: formatEnum(heatZone), color: .red)
                    }
                    if let habit = expense.habitSignature {
                        insightRow(icon: "arrow.triangle.2.circlepath", title: "Habit", value: formatEnum(habit), color: .blue)
                    }
                    if let emotion = expense.emotion {
                        insightRow(icon: "face.smiling.fill", title: "Emotion", value: formatEnum(emotion), color: .pink)
                    }
                    if let context = expense.context {
                        insightRow(icon: "tag.fill", title: "Context", value: formatEnum(context), color: .purple)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardColor, in: RoundedRectangle(cornerRadius: isExpanded ? 20 : 16))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 20 : 16)
                .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
        )
        .matchedGeometryEffect(id: "card_\(expense.id)", in: namespace)
    }
    
    private func insightRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }
    
    private func formatEnum(_ text: String) -> String {
        return text.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
