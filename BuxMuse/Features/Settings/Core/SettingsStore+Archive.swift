//
//  SettingsStore+Archive.swift
//  BuxMuse
//
//  Backup / restore helpers for BuxMuse archive.
//

import Foundation

extension SettingsStore {
    private static let archiveFeatureFlagKeys = [
        "buxmuse.sidehustle.enabled",
        "buxmuse.sidehustle.showUnassigned",
        "buxmuse.paymentsource.enabled",
        "buxmuse.cashdrawer.enabled",
        "buxmuse.barter.enabled",
        "buxmuse.scopecreep.enabled",
        "buxmuse.agreementscratchpad.enabled",
        "buxmuse.dataguard.enabled"
    ]

    func exportFeatureFlagsForArchive() -> [String: Bool] {
        var flags: [String: Bool] = [:]
        for key in Self.archiveFeatureFlagKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                flags[key] = UserDefaults.standard.bool(forKey: key)
            }
        }
        return flags
    }

    func importFeatureFlagsFromArchive(_ flags: [String: Bool]) {
        for (key, value) in flags {
            UserDefaults.standard.set(value, forKey: key)
        }
        sideHustleMatrixEnabled = UserDefaults.standard.bool(forKey: "buxmuse.sidehustle.enabled")
        showUnassignedExpensesInWorkspace = UserDefaults.standard.object(forKey: "buxmuse.sidehustle.showUnassigned") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "buxmuse.sidehustle.showUnassigned")
        paymentSourceTrackingEnabled = UserDefaults.standard.object(forKey: "buxmuse.paymentsource.enabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "buxmuse.paymentsource.enabled")
        dualCashDrawerEnabled = UserDefaults.standard.bool(forKey: "buxmuse.cashdrawer.enabled")
        barterLoggerEnabled = UserDefaults.standard.bool(forKey: "buxmuse.barter.enabled")
        antiScopeCreepEnabled = UserDefaults.standard.bool(forKey: "buxmuse.scopecreep.enabled")
        agreementScratchpadEnabled = UserDefaults.standard.bool(forKey: "buxmuse.agreementscratchpad.enabled")
        dataGuardModeEnabled = UserDefaults.standard.bool(forKey: "buxmuse.dataguard.enabled")
    }
}
