//
//  AdjustGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Premium bottom sheet for rapid adjustments of savings targets, schedules, and priorities.
//

import SwiftUI

struct AdjustGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    
    let goal: Goal
    
    @State private var targetString: String = ""
    @State private var selectDeadline = false
    @State private var deadline: Date = Date()
    @State private var priority: Int = 2
    
    private var cardColor: Color { themeManager.cardFill(for: colorScheme) }

    private var backgroundColor: Color { themeManager.screenBackground(for: colorScheme) }
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            BuxHeroMeshBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Adjust Goal")
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
                        
                        // Current Target reference header card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CURRENT SAVED STATUS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                    .kerning(1.0)
                                
                                Text("\(appSettingsManager.format(goal.currentAmount)) of \(appSettingsManager.format(goal.targetAmount))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Capsule()
                                    .fill(themeManager.current.accentColor.opacity(0.12))
                                    .frame(width: 60, height: 26)
                                
                                Text(priorityLabel(goal.priority))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                        }
                        .padding(16)
                        .background(cardColor)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                        )
                        
                        // 1. Adjust Target
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADJUST TARGET AMOUNT")
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
                        
                        // 2. Adjust Deadline
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ADJUST TARGET DEADLINE")
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
                        
                        // 3. Adjust Priority level
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADJUST PRIORITY LEVEL")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            HStack(spacing: 8) {
                                ForEach([1, 2, 3], id: \.self) { prio in
                                    let isSelected = priority == prio
                                    let prioLabel = priorityLabel(prio)
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
                    if let target = Decimal(string: targetString), target > 0 {
                        goalsViewModel.adjustGoal(
                            id: goal.id,
                            targetAmount: target,
                            deadline: selectDeadline ? deadline : nil,
                            priority: priority
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }) {
                    Text("Apply Adjustments")
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
            self.targetString = String(format: "%.0f", NSDecimalNumber(decimal: goal.targetAmount).doubleValue)
            if let dl = goal.deadline {
                self.deadline = dl
                self.selectDeadline = true
            }
            self.priority = goal.priority
        }
    }
    
    private func priorityLabel(_ prio: Int) -> String {
        prio == 1 ? "High" : (prio == 2 ? "Medium" : "Low")
    }
}
