//
//  PersonalHustleEntitySync.swift
//  BuxMuse
//

import Foundation

enum PersonalHustleEntitySync {
    @MainActor
    static func exportAll(from manager: HustleManager) -> [PersonalSyncEntityRecord] {
        let deviceId = PersonalSyncDeviceIdentity.currentDeviceId
        let revision = Date()
        var records: [PersonalSyncEntityRecord] = []
        for hustle in manager.hustles {
            records.append(makeRecord(
                kind: .hustle,
                entityId: hustle.id.uuidString,
                encodable: hustle,
                revision: revision,
                deviceId: deviceId
            ))
        }
        if let selected = manager.selectedHustleId {
            records.append(makeRecord(
                kind: .selection,
                entityId: "selected",
                encodable: HustleSelectionEntity(selectedHustleId: selected),
                revision: revision,
                deviceId: deviceId
            ))
        }
        return records
    }

    static func merge(local: [PersonalSyncEntityRecord], remote: [PersonalSyncEntityRecord]) -> (merged: [PersonalSyncEntityRecord], conflicts: [PersonalSyncConflict]) {
        PersonalEntityMergeEngine.mergeEntities(local: local, remote: remote, kind: .hustleEntity, defaultTitleKey: "Workspace conflict")
    }

    @MainActor
    static func apply(_ records: [PersonalSyncEntityRecord], to manager: HustleManager) {
        var hustles = manager.hustles
        var selectedId = manager.selectedHustleId
        let decoder = JSONDecoder()

        for record in records where record.entityKind.hasPrefix("hustle.") {
            guard let data = record.payloadJSON.data(using: .utf8) else { continue }
            if record.entityKind == PersonalHustleEntityKind.selection.cloudKind {
                if record.isDeleted {
                    selectedId = nil
                } else if let selection = try? decoder.decode(HustleSelectionEntity.self, from: data) {
                    selectedId = selection.selectedHustleId
                }
                continue
            }
            guard record.entityKind == PersonalHustleEntityKind.hustle.cloudKind else { continue }
            if record.isDeleted, let uuid = UUID(uuidString: record.entityId) {
                hustles.removeAll { $0.id == uuid }
                continue
            }
            guard let hustle = try? decoder.decode(Hustle.self, from: data) else { continue }
            if let index = hustles.firstIndex(where: { $0.id == hustle.id }) {
                hustles[index] = hustle
            } else {
                hustles.append(hustle)
            }
        }
        manager.replaceAll(hustles, selectedId: selectedId, notifyCloudSync: false)
    }

    static func recordName(for record: PersonalSyncEntityRecord) -> String {
        "personal-hustle-\(record.entityKind)-\(record.entityId)"
    }

    private struct HustleSelectionEntity: Codable {
        var selectedHustleId: UUID
    }

    private static func makeRecord<T: Encodable>(
        kind: PersonalHustleEntityKind,
        entityId: String,
        encodable: T,
        revision: Date,
        deviceId: String
    ) -> PersonalSyncEntityRecord {
        let data = (try? JSONEncoder().encode(encodable)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return PersonalSyncEntityRecord(
            entityKind: kind.cloudKind,
            entityId: entityId,
            payloadJSON: json,
            updatedAt: revision,
            deviceId: deviceId,
            contentHash: PersonalSyncContentHash.hash(json: json)
        )
    }
}

extension PersonalHustleEntityKind {
    nonisolated var cloudKind: String {
        switch self {
        case .hustle: return "hustle.hustle"
        case .selection: return "hustle.selection"
        }
    }

    static func from(cloudKind: String) -> PersonalHustleEntityKind? {
        switch cloudKind {
        case "hustle.hustle": return .hustle
        case "hustle.selection": return .selection
        default: return nil
        }
    }
}
