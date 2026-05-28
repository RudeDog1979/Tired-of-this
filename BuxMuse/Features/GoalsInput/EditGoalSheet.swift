//
//  EditGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Premium bottom sheet for editing existing savings goals.
//

import SwiftUI

struct EditGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    
    let goal: Goal
    
    @State private var name: String = ""
    @State private var targetString: String = ""
    @State private var selectDeadline = false
    @State private var deadline: Date = Date()
    @State private var priority: Int = 2
    @State private var notes: String = ""
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 13/255, green: 14/255, blue: 18/255) : Color(red: 242/255, green: 244/255, blue: 247/255)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Edit Goal")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    Spacer()
                    
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.vertical, 16)
                
                Divider().opacity(0.08)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1. Goal Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOAL NAME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            TextField("Enter goal name", text: $name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                .padding(.horizontal, BuxLayout.marginHorizontal)
                                .padding(.vertical, 16)
                                .background(cardColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                        }
                        
                        // 2. Target Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TARGET AMOUNT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            HStack(spacing: 8) {
                                Text(appSettingsManager.selectedCurrency.symbol)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.accentColor)
                                
                                TextField("0.00", text: $targetString)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    .keyboardType(.decimalPad)
                                    .tint(themeManager.current.accentColor)
                            }
                            .padding(.horizontal, BuxLayout.marginHorizontal)
                            .padding(.vertical, 16)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                        }
                        
                        // 3. Deadline Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("DEADLINE (OPTIONAL)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                    .kerning(1.2)
                                
                                Spacer()
                                
                                Toggle("", isOn: $selectDeadline)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: themeManager.current.accentColor))
                            }
                            
                            if selectDeadline {
                                DatePicker(
                                    "",
                                    selection: $deadline,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .padding(12)
                                .background(cardColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                                .tint(themeManager.current.accentColor)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        
                        // 4. Priority Pill Segment
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRIORITY LEVEL")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            HStack(spacing: 8) {
                                ForEach([1, 2, 3], id: \.self) { prio in
                                    let isSelected = priority == prio
                                    let prioLabel = prio == 1 ? "High" : (prio == 2 ? "Medium" : "Low")
                                    let activeColor = prio == 1 ? Color.red : (prio == 2 ? themeManager.current.accentColor : Color.gray)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                            priority = prio
                                        }
                                    }) {
                                        Text(prioLabel)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isSelected ? .white : Color(red: 120/255, green: 125/255, blue: 135/255))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(isSelected ? activeColor : cardColor)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // 5. Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            TextField("Notes or memo...", text: $notes)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, BuxLayout.marginHorizontal)
                                .padding(.vertical, 16)
                                .background(cardColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            
            // Sticky Save Changes Button
            VStack {
                Spacer()
                
                Button(action: {
                    if let target = Decimal(string: targetString), target > 0, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        goalsViewModel.updateGoal(
                            id: goal.id,
                            name: name,
                            targetAmount: target,
                            deadline: selectDeadline ? deadline : nil,
                            priority: priority,
                            notes: notes.isEmpty ? nil : notes
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }) {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: themeManager.current.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(BuxMicroShrinkStyle())
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            self.name = goal.name
            self.targetString = String(format: "%.0f", NSDecimalNumber(decimal: goal.targetAmount).doubleValue)
            if let dl = goal.deadline {
                self.deadline = dl
                self.selectDeadline = true
            }
            self.priority = goal.priority
            self.notes = goal.notes ?? ""
        }
    }
}
