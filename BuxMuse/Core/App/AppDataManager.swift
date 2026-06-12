//
//  AppDataManager.swift
//  BuxMuse
//
//  Facade for user-scoped reference data (country tax lookup).
//

import Foundation
import Combine

@MainActor
public final class AppDataManager: ObservableObject {
    private let studioStore: StudioStore
    private let taxManager: TaxManager
    private let appSettings: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()

    public var userCountryCode: String {
        appSettings.selectedCountry.id
    }

    public var userTaxInfo: TaxInfo? {
        taxManager.taxForUser(country: userCountryCode)
    }

    public var taxManagerRef: TaxManager { taxManager }

    /// Saved user-editable tax reference (not auto-filled from business country).
    public var savedTaxReference: StudioTaxProfile {
        studioStore.taxProfile
    }

    init(studioStore: StudioStore, taxManager: TaxManager, appSettings: AppSettingsManager) {
        self.studioStore = studioStore
        self.taxManager = taxManager
        self.appSettings = appSettings

        studioStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        taxManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        appSettings.$selectedCountry
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
