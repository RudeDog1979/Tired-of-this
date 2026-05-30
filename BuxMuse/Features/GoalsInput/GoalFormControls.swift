//
//  GoalFormControls.swift
//  BuxMuse
//
//  Shared native Form controls for goal sheets.
//

import SwiftUI

struct GoalPriorityPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var priority: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach([1, 2, 3], id: \.self) { prio in
                let isSelected = priority == prio
                let label = prio == 1 ? "High" : (prio == 2 ? "Medium" : "Low")
                let activeColor = prio == 1 ? Color.red : (prio == 2 ? themeManager.current.accentColor : Color.gray)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        priority = prio
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isSelected ? .white : themeManager.labelSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? activeColor : themeManager.cardFill(for: colorScheme))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GoalOptionalDeadlineSection: View {
    @Binding var isEnabled: Bool
    @Binding var date: Date

    var body: some View {
        Toggle("Set deadline", isOn: $isEnabled.animation())
        if isEnabled {
            DatePicker("Deadline", selection: $date, in: Date()..., displayedComponents: .date)
        }
    }
}
