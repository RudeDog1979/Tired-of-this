//
//  WorkspaceROIEngine.swift
//  BuxMuse
//
//  Read-only cross-workspace flow summary from synergy bridge ledger rows.
//

import Foundation

public struct WorkspaceSynergyFlowLine: Equatable, Identifiable {
    public var sourceHustleId: UUID
    public var targetHustleId: UUID
    public var sourceName: String
    public var targetName: String
    public var totalAmount: Decimal
    public var eventCount: Int

    public var id: String { "\(sourceHustleId.uuidString)-\(targetHustleId.uuidString)" }
}

public struct WorkspaceSynergySummary: Equatable {
    public var flows: [WorkspaceSynergyFlowLine]
    public var splitGroupsThisMonth: Int

    public static let empty = WorkspaceSynergySummary(flows: [], splitGroupsThisMonth: 0)
}

enum WorkspaceROIEngine {
    static func summarize(
        records: [ExpenseRecord],
        hustles: [Hustle],
        now: Date = Date()
    ) -> WorkspaceSynergySummary {
        let names = Dictionary(uniqueKeysWithValues: hustles.map { ($0.id, $0.name) })
        var flowTotals: [String: (source: UUID, target: UUID, amount: Decimal, count: Int)] = [:]

        for record in records {
            guard record.synergyBridgeKind == .dividendTransfer,
                  record.bridgeRole == SynergyBridgeRole.transferOut.rawValue,
                  let source = record.hustleId,
                  let target = record.bridgeCounterpartyHustleId else { continue }

            let key = "\(source.uuidString)-\(target.uuidString)"
            var bucket = flowTotals[key] ?? (source, target, 0, 0)
            bucket.amount += abs(record.amountValue)
            bucket.count += 1
            flowTotals[key] = bucket
        }

        let flows = flowTotals.values
            .compactMap { entry -> WorkspaceSynergyFlowLine? in
                guard let sourceName = names[entry.source],
                      let targetName = names[entry.target] else { return nil }
                return WorkspaceSynergyFlowLine(
                    sourceHustleId: entry.source,
                    targetHustleId: entry.target,
                    sourceName: sourceName,
                    targetName: targetName,
                    totalAmount: entry.amount,
                    eventCount: entry.count
                )
            }
            .sorted { $0.totalAmount > $1.totalAmount }

        let monthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        let splitGroupIds = Set(
            records
                .filter { $0.synergyBridgeKind == .split && $0.date >= monthStart }
                .compactMap(\.bridgeGroupId)
        )

        return WorkspaceSynergySummary(flows: flows, splitGroupsThisMonth: splitGroupIds.count)
    }
}

enum WorkspaceExpenseRowChrome {
    static func workspaceLabel(for hustleId: UUID?, hustles: [Hustle]) -> String? {
        guard SettingsStore.shared.sideHustleMatrixEnabled else { return nil }
        guard let hustleId,
              let hustle = hustles.first(where: { $0.id == hustleId }) else { return nil }
        return hustle.name
    }

    static func bridgeBadge(for record: ExpenseRecord, hustles: [Hustle]) -> String? {
        guard SettingsStore.shared.sideHustleMatrixEnabled,
              let kind = record.synergyBridgeKind else { return nil }

        let names = Dictionary(uniqueKeysWithValues: hustles.map { ($0.id, $0.name) })

        let locale = BuxInterfaceLocale.currentInterfaceLocale

        switch kind {
        case .split:
            if let share = record.bridgeSharePercent {
                return BuxLocalizedString.format("Split %lld%%", locale: locale, Int(share.rounded()))
            }
            return BuxLocalizedString.string("Split", locale: locale)
        case .dividendTransfer:
            guard let counterpartyId = record.bridgeCounterpartyHustleId,
                  let counterpartyName = names[counterpartyId] else {
                return BuxLocalizedString.string("Transfer", locale: locale)
            }
            switch record.bridgeRole.flatMap({ SynergyBridgeRole(rawValue: $0) }) {
            case .transferOut:
                return BuxLocalizedString.format("Transfer to %@", locale: locale, counterpartyName)
            case .transferIn:
                return BuxLocalizedString.format("Transfer from %@", locale: locale, counterpartyName)
            default:
                return BuxLocalizedString.string("Transfer", locale: locale)
            }
        }
    }
}
