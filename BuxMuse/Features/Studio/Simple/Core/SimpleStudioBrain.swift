//
//  SimpleStudioBrain.swift
//  BuxMuse
//
//  Publishes Simple Studio UI snapshots from the store.
//

import Foundation
import Combine

@MainActor
public final class SimpleStudioBrain: ObservableObject {
    @Published private(set) var hubDisplay: SimpleStudioHubDisplay = .empty
    @Published private(set) var myMoneyDisplay: SimpleMyMoneyDisplay = .empty

    private let store: SimpleStudioStore
    private let settings: SettingsStore
    private let studioStore: StudioStore
    private let appSettings: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()

    init(
        store: SimpleStudioStore,
        settings: SettingsStore,
        studioStore: StudioStore,
        appSettings: AppSettingsManager
    ) {
        self.store = store
        self.settings = settings
        self.studioStore = studioStore
        self.appSettings = appSettings
        wireRefreshTriggers()
        refreshAll()
    }

    func refreshAll() {
        guard settings.studioEnabled, settings.studioMode == .simple else {
            hubDisplay = .empty
            myMoneyDisplay = .empty
            return
        }
        let title = studioStore.profile.businessName.isEmpty
            ? studioStore.profile.displayName
            : studioStore.profile.businessName
        let format: (Decimal) -> String = { [appSettings] in appSettings.format($0) }
        let locale = appSettings.interfaceLocale
        hubDisplay = SimpleStudioEngine.buildHubDisplay(
            snapshot: store.snapshot,
            businessTitle: title,
            persona: settings.studioPersona,
            format: format,
            locale: locale
        )
        myMoneyDisplay = SimpleStudioEngine.buildMyMoneyDisplay(
            snapshot: store.snapshot,
            persona: settings.studioPersona,
            format: format,
            locale: locale
        )
    }

    private func wireRefreshTriggers() {
        // Refresh after store properties change — not on objectWillChange (fires too early).
        Publishers.MergeMany(
            store.$entries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            store.$customers.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            store.$invoices.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            store.$hourlyRateHint.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            store.$businessCard.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.refreshAll() }
        .store(in: &cancellables)

        settings.$studioMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        settings.$studioPersona
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        settings.$studioEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        studioStore.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        appSettings.$selectedCurrency
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        appSettings.$selectedCountry
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)
    }
}
