//
//  MoneyMapExperience.swift
//  BuxMuse
//
//  One-time full-map intro and other persisted experience flags.
//

import Foundation

enum MoneyMapExperience {
    private static let firstFullOpenKey = "buxmuse.moneymap.didPlayFirstFullOpen"

    static var shouldPlayFirstFullOpenExpand: Bool {
        !UserDefaults.standard.bool(forKey: firstFullOpenKey)
    }

    static func markFirstFullOpenExpandPlayed() {
        UserDefaults.standard.set(true, forKey: firstFullOpenKey)
    }
}
