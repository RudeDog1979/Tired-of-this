//
//  GoalDetailView.swift
//  BuxMuse
//  Features/Goals/
//
//  Premium detailed savings goal overlay view matching the standard BuxMuse modal sheet styling.
//  Optimized: Runs 100% on flat pre-computed Brain values at a solid 120 FPS.
//

import SwiftUI

struct GoalDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    
    let detail: GoalsViewModel.GoalDetailState
    let onAddContribution: (UUID, Decimal, String?) -> Void
    let onDeleteGoal: (UUID) -> Void
    @Binding var isPresented: Bool
    
    // Bottom Sheet presentations state
    @State private var showEditGoal = false
    @State private var showContributeGoal = false
    @State private var showAdjustGoal = false
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var body: some View {
        ZStack {
            // Dark Backdrop
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Row with Close
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : .white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }
                        }
                        
                        Spacer()
                        
                        Text("Goal Details")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        
                        Spacer()
                        
                        Image(systemName: "xmark.circle.fill").opacity(0)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 60)
                    
                    // 1. MAIN OVERVIEW CARD
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(cardColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                        
                        VStack(spacing: 20) {
                            // Icon Badge
                            ZStack {
                                Circle()
                                    .fill(themeManager.current.accentColor.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: "target")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                            .shadow(radius: 2)
                            
                            VStack(spacing: 6) {
                                Text(detail.goal.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                
                                if let notes = detail.goal.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                            }
                            
                            // Saved Progress
                            VStack(spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(appSettingsManager.format(detail.goal.currentAmount))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    
                                    Text("saved")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                                
                                // Progress Bar (Pre-computed flat 120 FPS binding)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(themeManager.current.accentColor)
                                            .frame(width: geo.size.width * CGFloat(detail.progress), height: 8)
                                    }
                                }
                                .frame(height: 8)
                                .padding(.horizontal, 12)
                                
                                HStack {
                                    Text("Target: \(appSettingsManager.format(detail.goal.targetAmount))")
                                    Spacer()
                                    Text("\(Int(detail.progress * 100))%")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                            }
                            
                            Divider().opacity(0.08)
                            
                            // Health Score and Forecast Status
                            HStack {
                                Label("Health Score: \(detail.health.score)%", systemImage: "heart.text.square.fill")
                                    .foregroundColor(detail.health.score >= 75 ? .green : (detail.health.score >= 45 ? .orange : .red))
                                
                                Spacer()
                                
                                Label("Forecast: \(detail.timelineAI.delayRisk) Risk", systemImage: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(detail.timelineAI.delayRisk == "Low" ? .green : (detail.timelineAI.delayRisk == "Medium" ? .orange : .red))
                            }
                            .font(.system(size: 12, weight: .bold))
                        }
                        .padding(28)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // 2. INTERACTIVE GOALS OPERATIONS ROW
                    HStack(spacing: 12) {
                        // A. Log Contribution
                        Button(action: {
                            showContributeGoal = true
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Save Money")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.current.accentColor)
                            .cornerRadius(16)
                        }
                        
                        // B. Adjust Target / Priorities
                        Button(action: {
                            showAdjustGoal = true
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 18))
                                Text("Adjust")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(cardColor)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                        }
                        
                        // C. Edit Settings
                        Button(action: {
                            showEditGoal = true
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 18))
                                Text("Edit Goal")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(cardColor)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .buttonStyle(BuxMicroShrinkStyle())
                    
                    // 3. ALTERNATIVE SCENARIO PATHWAYS
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SAVINGS VELOCITY SCENARIOS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                            .kerning(1.2)
                        
                        VStack(spacing: 12) {
                            ForEach(detail.timelineAI.scenarios) { scenario in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(scenario.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                        
                                        Text(scenario.description)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(formatDate(scenario.projectedDate))
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(themeManager.current.accentColor)
                                        
                                        Text("Delay Risk: \(scenario.delayRisk)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(scenario.delayRisk == "Low" ? .green : (scenario.delayRisk == "Medium" ? .orange : .red))
                                    }
                                }
                                .padding(16)
                                .background(cardColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // 4. DETECTED RISK WARNINGS
                    if !detail.risks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DETECTED PROGRESS THREATS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                                .kerning(1.2)
                            
                            ForEach(detail.risks) { risk in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(risk.description)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    }
                                    
                                    Text("Fix: \(risk.suggestedFix)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.leading, 22)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                    }
                    
                    // 5. BUDGET REDIRECTION OPPORTUNITIES
                    if !detail.opportunities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SMART SAVINGS REDIRECTIONS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                                .kerning(1.2)
                            
                            ForEach(detail.opportunities) { opportunity in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.green)
                                        Text(opportunity.description)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    }
                                    
                                    Text(opportunity.benefit)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding(.leading, 22)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                    }
                    
                    // 6. SAVINGS MOMENTUM & HABITS CARD
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SAVINGS MOMENTUM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                            .kerning(1.2)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(cardColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Status: \(detail.momentum.statusDescription)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%+.1f", detail.momentum.score))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(detail.momentum.score >= 0.2 ? .green : (detail.momentum.score <= -0.2 ? .red : .orange))
                                }
                                
                                // Momentum Score indicator bar (Pre-computed flat 120 FPS binding)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                            .frame(height: 6)
                                        
                                        Capsule()
                                            .fill(detail.momentum.score >= 0.2 ? .green : (detail.momentum.score <= -0.2 ? .red : .orange))
                                            .frame(width: geo.size.width * CGFloat(detail.normalizedScore), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                
                                if !detail.momentum.microActions.isEmpty {
                                    Divider().opacity(0.08)
                                    
                                    Text("Suggested Actions:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    
                                    ForEach(detail.momentum.microActions, id: \.self) { act in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(themeManager.current.accentColor)
                                                .padding(.top, 2)
                                            
                                            Text(act)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                }
                                
                                if !detail.momentum.habitActions.isEmpty {
                                    Divider().opacity(0.08)
                                    
                                    Text("Habit Builders:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    
                                    ForEach(detail.momentum.habitActions, id: \.self) { act in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(themeManager.current.accentColor)
                                                .padding(.top, 2)
                                            
                                            Text(act)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                }
                            }
                            .padding(20)
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // 7. CONTRIBUTION HISTORY CARD (Pre-computed flat sorted array)
                    if !detail.sortedContributions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SAVINGS LOG")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            VStack(spacing: 1) {
                                ForEach(detail.sortedContributions) { contrib in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(contrib.notes ?? "Goal contribution")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                            
                                            Text(formatDate(contrib.date))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("+\(appSettingsManager.format(contrib.amount))")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.green)
                                    }
                                    .padding(16)
                                    .background(cardColor)
                                }
                            }
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                    }
                    
                    // 8. RED DELETE GOAL TRIGGER BUTTON
                    Button(action: {
                        onDeleteGoal(detail.goal.id)
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Text("Delete Goal & Discard savings data")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .shadow(color: Color.red.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            (colorScheme == .dark ? Color(red: 13/255, green: 14/255, blue: 18/255) : Color(red: 242/255, green: 244/255, blue: 247/255))
                .ignoresSafeArea()
        )
        // Sheets Presentations for Edit, Contribute, Adjust Actions
        .sheet(isPresented: $showEditGoal) {
            EditGoalSheet(goal: detail.goal)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
        }
        .sheet(isPresented: $showContributeGoal) {
            ContributeToGoalSheet(goal: detail.goal)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
        }
        .sheet(isPresented: $showAdjustGoal) {
            AdjustGoalSheet(goal: detail.goal)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd, yyyy"
        return fmt.string(from: date)
    }
}
