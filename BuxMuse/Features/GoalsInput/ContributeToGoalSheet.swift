//
//  ContributeToGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Premium bottom sheet for logging goal savings contributions with predictive micro-advice.
//

import SwiftUI

struct ContributeToGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    
    let goal: Goal
    
    @State private var amountString: String = ""
    @State private var notes: String = ""
    @State private var date: Date = Date()
    @State private var microSuggestion: String? = nil
    
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
                    
                    Text("Contribute")
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
                        
                        // BRAIN REDIRECTION CARD
                        if let suggestion = microSuggestion {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BRAIN SAVINGS TIP")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                                    .kerning(1.2)
                                
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 15))
                                        .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(suggestion)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : Color(red: 40/255, green: 40/255, blue: 40/255))
                                            .multilineTextAlignment(.leading)
                                        
                                        Button(action: {
                                            // Extract numeric suggestion value
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                self.amountString = "15"
                                                self.notes = "Brain micro-savings redirection"
                                            }
                                        }) {
                                            Text("Redirect suggested amount")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(themeManager.current.accentColor)
                                                .padding(.top, 2)
                                        }
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        
                        // 1. Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONTRIBUTION AMOUNT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                .kerning(1.2)
                            
                            HStack(spacing: 8) {
                                Text(appSettingsManager.selectedCurrency.symbol)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.accentColor)
                                
                                TextField("0.00", text: $amountString)
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
                        
                        // 2. Note
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MEMO / SOURCE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                .kerning(1.2)
                            
                            TextField("e.g. Weekly savings, Salary redirection, Gift", text: $notes)
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
                        
                        // 3. Date
                        DatePicker(
                            "Contribution Date",
                            selection: $date,
                            displayedComponents: .date
                        )
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
                        .tint(themeManager.current.accentColor)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            
            // Sticky Log Contribution Button
            VStack {
                Spacer()
                
                Button(action: {
                    if let amount = Decimal(string: amountString), amount > 0 {
                        goalsViewModel.addContribution(
                            toGoalId: goal.id,
                            amount: amount,
                            notes: notes.isEmpty ? "Direct contribution" : notes
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }) {
                    Text("Confirm Contribution")
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
            setupMicroSuggestions()
        }
    }
    
    private func setupMicroSuggestions() {
        let details = goalsViewModel.selectedGoalDetail
        if let opp = details?.opportunities.first {
            self.microSuggestion = "Cancel or optimize: \(opp.description) benefits \(opp.benefit)."
        } else {
            self.microSuggestion = "Trim £15.00 from active subscription overspends and redirect it to achieve \(goal.name) sooner."
        }
    }
}
