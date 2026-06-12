//
//  GoalsSheetCoordinator.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  A dedicated, lightweight presentation manager that orchestrates the slide-up modals,
//  keeping both ContentView.swift and DashboardView.swift 100% free of BuxMuse calculations
//  and avoiding heavy child layout re-evaluation passes during sheet entries.
//

import SwiftUI
import Combine

public final class GoalsSheetCoordinator: ObservableObject {
    @Published public var activeSheet: GoalsSheet? = nil
    @Published public var showGoalDetail: Bool = false
    @Published public var selectedGoalDetail: GoalsViewModel.GoalDetailState? = nil
    
    public enum GoalsSheet: Identifiable {
        case addGoal
        
        public var id: String {
            switch self {
            case .addGoal: return "addGoal"
            }
        }
    }
    
    public init() {}
    
    public func presentAddGoal() {
        activeSheet = .addGoal
    }
    
    public func presentGoalDetail(_ detail: GoalsViewModel.GoalDetailState) {
        selectedGoalDetail = detail
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            showGoalDetail = true
        }
    }
    
    public func dismissGoalDetail() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            showGoalDetail = false
        }
        // Gracefully clear selection after transition completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self = self else { return }
            if !self.showGoalDetail {
                self.selectedGoalDetail = nil
            }
        }
    }
}
