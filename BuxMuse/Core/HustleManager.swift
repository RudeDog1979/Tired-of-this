//
//  HustleManager.swift
//  BuxMuse
//
//  Global manager for Side-Hustles (Multi-Gig Ledger) and active Gig filtering.
//

import Foundation
import Combine
import SwiftUI

public struct Hustle: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var isActive: Bool

    // Workspace Nexus — optional; nil decodes from legacy saves.
    public var themeName: String?
    public var currencyCode: String?
    public var cardRules: [String]?
    public var merchantRules: [String]?
    public var budgetLimit: Decimal?

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#5A55F5",
        isActive: Bool = true,
        themeName: String? = nil,
        currencyCode: String? = nil,
        cardRules: [String]? = nil,
        merchantRules: [String]? = nil,
        budgetLimit: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isActive = isActive
        self.themeName = themeName
        self.currencyCode = currencyCode
        self.cardRules = cardRules
        self.merchantRules = merchantRules
        self.budgetLimit = budgetLimit
    }
}

@MainActor
public final class HustleManager: ObservableObject {
    public static let shared = HustleManager()
    
    @Published public private(set) var hustles: [Hustle] = []
    @Published public var selectedHustleId: UUID? = nil
    
    private let storeKey = "buxmuse.sidehustles.list"
    private let activeHustleKey = "buxmuse.sidehustles.selectedId"
    private static let sideHustleMatrixEnabledKey = "buxmuse.sidehustle.enabled"
    
    private init() {
        loadHustles()
    }
    
    public func loadHustles() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([Hustle].self, from: data) {
            self.hustles = decoded
        } else {
            self.hustles = []
        }

        if UserDefaults.standard.bool(forKey: Self.sideHustleMatrixEnabledKey),
           let idStr = UserDefaults.standard.string(forKey: activeHustleKey),
           let uuid = UUID(uuidString: idStr),
           hustles.contains(where: { $0.id == uuid }) {
            self.selectedHustleId = uuid
        } else {
            self.selectedHustleId = nil
        }
    }
    
    public func saveHustles() {
        if let encoded = try? JSONEncoder().encode(hustles) {
            UserDefaults.standard.set(encoded, forKey: storeKey)
        }
        if let selectedId = selectedHustleId {
            UserDefaults.standard.set(selectedId.uuidString, forKey: activeHustleKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeHustleKey)
        }
    }
    
    public func selectHustle(_ id: UUID?) {
        selectedHustleId = id
        saveHustles()
    }
    
    public var activeHustlesCount: Int {
        hustles.filter { $0.isActive }.count
    }
    
    public func canAddHustle() -> Bool {
        let isPro = SettingsStore.shared.studioMode == .pro
        if isPro {
            return true
        } else {
            return activeHustlesCount < 3
        }
    }
    
    @discardableResult
    public func addHustle(name: String, colorHex: String) -> Bool {
        guard canAddHustle() else { return false }
        let newHustle = Hustle(name: name, colorHex: colorHex, isActive: true)
        hustles.append(newHustle)
        saveHustles()
        return true
    }
    
    public func updateHustle(_ updated: Hustle) {
        guard let index = hustles.firstIndex(where: { $0.id == updated.id }) else { return }
        hustles[index] = updated
        saveHustles()
    }
    
    public func deleteHustle(id: UUID) {
        hustles.removeAll { $0.id == id }
        if selectedHustleId == id {
            selectedHustleId = nil
        }
        saveHustles()
    }

    public func replaceAll(_ newHustles: [Hustle], selectedId: UUID? = nil) {
        hustles = newHustles
        selectedHustleId = selectedId
        saveHustles()
    }

    /// Evaluates auto-routing rules for unassigned expenses. First active workspace match wins.
    public func routeHustleId(merchantName: String, notes: String?, paymentMethod: String?) -> UUID? {
        let cleanMerchant = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanNotes = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPM = (paymentMethod ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for hustle in hustles where hustle.isActive {
            if let cardRules = hustle.cardRules {
                for suffix in cardRules {
                    let clean = suffix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !clean.isEmpty, cleanPM.contains(clean) {
                        return hustle.id
                    }
                }
            }
            if let merchantRules = hustle.merchantRules {
                for keyword in merchantRules {
                    let clean = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !clean.isEmpty,
                       cleanMerchant.contains(clean) || cleanNotes.contains(clean) {
                        return hustle.id
                    }
                }
            }
        }
        return nil
    }

    public func resetAllData() {
        hustles = []
        selectedHustleId = nil
        UserDefaults.standard.removeObject(forKey: storeKey)
        UserDefaults.standard.removeObject(forKey: activeHustleKey)
    }

    /// Ensures at least one workspace exists after enabling the matrix (optional first workspace).
    @discardableResult
    public func ensureDefaultWorkspaceIfNeeded() -> Bool {
        guard hustles.isEmpty else { return false }
        let workspace = Hustle(name: "Personal", colorHex: "#30D158", isActive: true)
        hustles = [workspace]
        saveHustles()
        return true
    }
}
