//
//  AddGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Premium bottom sheet for entering savings goals with predictive smart defaults.
//

import SwiftUI

struct AddGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    
    @State private var name: String = ""
    @State private var targetString: String = ""
    @State private var selectDeadline = false
    @State private var deadline: Date = Date().addingTimeInterval(180 * 86400)
    @State private var priority: Int = 2 // 1=High, 2=Medium, 3=Low
    @State private var notes: String = ""
    
    // Suggestion defaults cache
    @State private var brainSuggestions: GoalSuggestions? = nil
    
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
                    
                    Text("Add Goal")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    
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
                        
                        // BRAIN DYNAMIC DEFAULT CHIPS
                        if let suggestions = brainSuggestions {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BRAIN RECOMMENDATIONS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                                    .kerning(1.2)
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(themeManager.current.accentColor)
                                        .font(.system(size: 14, weight: .bold))
                                    
                                    Text("6-Month Emergency target: \(appSettingsManager.format(suggestions.suggestedTargetAmount))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Color(red: 70/255, green: 80/255, blue: 95/255))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            self.targetString = String(format: "%.0f", NSDecimalNumber(decimal: suggestions.suggestedTargetAmount).doubleValue)
                                            self.deadline = suggestions.suggestedDeadline
                                            self.selectDeadline = true
                                            self.priority = suggestions.suggestedPriority
                                        }
                                    }) {
                                        Text("Apply")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(themeManager.current.accentColor)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(12)
                                .background(themeManager.current.accentColor.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeManager.current.accentColor.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        
                        // 1. Goal Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOAL NAME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                .kerning(1.2)
                            
                            TextField("e.g. New Car, Laptop, Emergency Fund", text: $name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
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
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                .kerning(1.2)
                            
                            HStack(spacing: 8) {
                                Text(appSettingsManager.selectedCurrency.symbol)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.accentColor)
                                
                                TextField("0.00", text: $targetString)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
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
                        
                        // 3. Optional Deadline Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("DEADLINE (OPTIONAL)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
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
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
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
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                .kerning(1.2)
                            
                            TextField("Add a memo or specific details...", text: $notes)
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
            
            // Sticky Save Button
            VStack {
                Spacer()
                
                Button(action: {
                    if let target = Decimal(string: targetString), target > 0, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        goalsViewModel.createGoal(
                            name: name,
                            targetAmount: target,
                            currentAmount: 0,
                            deadline: selectDeadline ? deadline : nil,
                            priority: priority,
                            notes: notes.isEmpty ? nil : notes
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }) {
                    Text("Save Goal")
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
            self.brainSuggestions = goalsViewModel.getBrainSuggestions()
        }
    }
}
