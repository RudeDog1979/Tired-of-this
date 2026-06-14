//
//  AppTutorialCoordinator.swift
//  BuxMuse
//

import Combine
import SwiftUI

@MainActor
final class AppTutorialCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var currentStepIndex = 0
    @Published private(set) var steps: [TutorialStepDefinition] = []
    /// Bumped after navigation transitions so scroll hosts re-center the active anchor.
    @Published private(set) var layoutEpoch = 0
    @Published var pendingDashboardSheet: TutorialSheetAction = .none
    @Published var pendingSettingsDestination: SettingsDestinationType?
    @Published private(set) var pendingSettingsPopToRoot = false

    private let settingsStore: SettingsStore
    private weak var navigationCoordinator: NavigationCoordinator?
    private weak var appSettingsManager: AppSettingsManager?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func attach(
        navigationCoordinator: NavigationCoordinator,
        appSettingsManager: AppSettingsManager
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.appSettingsManager = appSettingsManager
    }

    private var locale: Locale {
        appSettingsManager?.interfaceLocale ?? .current
    }

    var currentStep: TutorialStepDefinition? {
        guard isActive, steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var stepProgressLabel: String {
        guard isActive, !steps.isEmpty else { return "" }
        return BuxLocalizedString.format(
            "Step %lld of %lld",
            locale: locale,
            currentStepIndex + 1,
            steps.count
        )
    }

    func startCoreTour(restart: Bool = false) {
        guard settingsStore.hasCompletedOnboarding else { return }
        if !restart, settingsStore.appTourFinished || settingsStore.appTourSkipped { return }

        steps = TutorialCoreSteps.all(studioEnabled: settingsStore.studioEnabled)
        currentStepIndex = 0
        isActive = true
        settingsStore.appTourPendingAutoStart = false
        applyEnterAction(for: currentStep)
        bumpLayoutEpoch(after: 0.5)
    }

    func requestAutoStartAfterOnboarding() {
        settingsStore.appTourPendingAutoStart = true
    }

    func consumeAutoStartIfNeeded() {
        guard settingsStore.appTourPendingAutoStart else { return }
        guard settingsStore.hasCompletedOnboarding, !isActive else { return }
        if settingsStore.appTourSkipped {
            settingsStore.appTourPendingAutoStart = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            guard self.settingsStore.appTourPendingAutoStart else { return }
            // Ignore stale finished flag from UserDefaults / older builds — onboarding just completed.
            self.startCoreTour(restart: true)
        }
    }

    func restartTour() {
        settingsStore.resetAppTourProgress()
        startCoreTour(restart: true)
    }

    func advanceNext() {
        guard isActive else { return }
        if currentStep?.isFinishStep == true {
            completeTour()
            return
        }
        guard currentStepIndex + 1 < steps.count else {
            completeTour()
            return
        }
        currentStepIndex += 1
        applyEnterAction(for: currentStep)
        bumpLayoutEpoch(after: 0.45)
    }

    func skipTour() {
        settingsStore.appTourSkipped = true
        settingsStore.appTourFinished = false
        settingsStore.save()
        tearDown()
    }

    func completeTour() {
        settingsStore.appTourFinished = true
        settingsStore.appTourSkipped = false
        settingsStore.save()
        tearDown()
    }

    func handleAnchorTap(_ id: TutorialAnchorID) {
        guard isActive, currentStep?.anchor == id else { return }
        switch id {
        case .homeIncomeButton:
            pendingDashboardSheet = .openAddIncome
            advanceNext()
        case .homeExpenseButton:
            pendingDashboardSheet = .openAddExpense
            advanceNext()
        default:
            advanceNext()
        }
    }

    func consumeDashboardSheetRequest() -> TutorialSheetAction {
        defer { pendingDashboardSheet = .none }
        return pendingDashboardSheet
    }

    func consumeSettingsDestinationRequest() -> SettingsDestinationType? {
        defer { pendingSettingsDestination = nil }
        return pendingSettingsDestination
    }

    func consumeSettingsPopToRoot() -> Bool {
        defer { pendingSettingsPopToRoot = false }
        return pendingSettingsPopToRoot
    }

    private func applyEnterAction(for step: TutorialStepDefinition?) {
        guard let step, let action = step.onEnter else { return }
        switch action {
        case .selectTab(let tab):
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigationCoordinator?.selectedTab = tab
            }
        case .openSettings(let destination):
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigationCoordinator?.selectedTab = .settings
            }
            pendingSettingsDestination = destination
        case .showSettingsOverview:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigationCoordinator?.selectedTab = .settings
            }
            pendingSettingsPopToRoot = true
        case .presentSheet(let sheet):
            pendingDashboardSheet = sheet
        }
        bumpLayoutEpoch(after: 0.55)
    }

    private func bumpLayoutEpoch(after delay: TimeInterval) {
        layoutEpoch += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.layoutEpoch += 1
        }
    }

    private func tearDown() {
        isActive = false
        steps = []
        currentStepIndex = 0
        pendingDashboardSheet = .none
        pendingSettingsDestination = nil
        pendingSettingsPopToRoot = false
        layoutEpoch += 1
    }

    func tearDownForFactoryReset() {
        settingsStore.resetAppTourProgress()
        tearDown()
    }
}
