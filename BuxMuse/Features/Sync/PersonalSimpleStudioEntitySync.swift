//
//  PersonalSimpleStudioEntitySync.swift
//  BuxMuse
//

import Foundation

enum PersonalSimpleStudioEntitySync {
    @MainActor
    static func exportAll(from store: SimpleStudioStore) -> [PersonalSyncEntityRecord] {
        let snapshot = store.snapshot
        let revision = store.lastPersistedAt ?? Date()
        let deviceId = PersonalSyncDeviceIdentity.currentDeviceId
        var records: [PersonalSyncEntityRecord] = []

        if let hint = snapshot.hourlyRateHint {
            records.append(makeRecord(kind: .hourlyRateHint, entityId: "hourly-rate", encodable: hint, revision: revision, deviceId: deviceId))
        }
        if let card = snapshot.businessCard {
            records.append(makeRecord(kind: .businessCard, entityId: "business-card", encodable: card, revision: revision, deviceId: deviceId))
        }
        for entry in snapshot.entries {
            records.append(makeRecord(kind: .entry, entityId: entry.id.uuidString, encodable: entry, revision: revision, deviceId: deviceId))
        }
        for customer in snapshot.customers {
            records.append(makeRecord(kind: .customer, entityId: customer.id.uuidString, encodable: customer, revision: revision, deviceId: deviceId))
        }
        for invoice in snapshot.invoices {
            records.append(makeRecord(kind: .invoice, entityId: invoice.id.uuidString, encodable: invoice, revision: revision, deviceId: deviceId))
        }
        return records
    }

    static func merge(local: [PersonalSyncEntityRecord], remote: [PersonalSyncEntityRecord]) -> (merged: [PersonalSyncEntityRecord], conflicts: [PersonalSyncConflict]) {
        PersonalEntityMergeEngine.mergeEntities(local: local, remote: remote, kind: .simpleStudioEntity, defaultTitleKey: "Simple Studio item conflict")
    }

    @MainActor
    static func apply(_ records: [PersonalSyncEntityRecord], to store: SimpleStudioStore) {
        var snapshot = store.snapshot
        for record in records where record.entityKind.hasPrefix("simple.") {
            guard !record.isDeleted else {
                remove(record, from: &snapshot)
                continue
            }
            apply(record, to: &snapshot)
        }
        store.apply(snapshot)
        store.save(notifyCloudSync: false)
    }

    static func recordName(for record: PersonalSyncEntityRecord) -> String {
        "personal-simple-\(record.entityKind)-\(record.entityId)"
    }

    private static func makeRecord<T: Encodable>(
        kind: PersonalSimpleStudioEntityKind,
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
            contentHash: PersonalSyncContentHash.hash(json: json),
            usesExternalAsset: data.count >= 100_000
        )
    }

    private static func apply(_ record: PersonalSyncEntityRecord, to snapshot: inout SimpleStudioSnapshot) {
        guard let kind = PersonalSimpleStudioEntityKind(cloudKind: record.entityKind),
              let data = record.payloadJSON.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        switch kind {
        case .hourlyRateHint:
            snapshot.hourlyRateHint = try? decoder.decode(Decimal.self, from: data)
        case .businessCard:
            snapshot.businessCard = try? decoder.decode(SimpleBusinessCard.self, from: data)
        case .entry:
            upsertUUID(record.entityId, in: &snapshot.entries, decode: SimpleStudioEntry.self, from: data, decoder: decoder)
        case .customer:
            upsertUUID(record.entityId, in: &snapshot.customers, decode: SimpleCustomerMemory.self, from: data, decoder: decoder)
        case .invoice:
            upsertUUID(record.entityId, in: &snapshot.invoices, decode: SimpleInvoice.self, from: data, decoder: decoder)
        }
    }

    private static func remove(_ record: PersonalSyncEntityRecord, from snapshot: inout SimpleStudioSnapshot) {
        guard let kind = PersonalSimpleStudioEntityKind(cloudKind: record.entityKind),
              let uuid = UUID(uuidString: record.entityId) else { return }
        switch kind {
        case .entry: snapshot.entries.removeAll { $0.id == uuid }
        case .customer: snapshot.customers.removeAll { $0.id == uuid }
        case .invoice: snapshot.invoices.removeAll { $0.id == uuid }
        case .businessCard: snapshot.businessCard = nil
        case .hourlyRateHint: snapshot.hourlyRateHint = nil
        }
    }

    private static func upsertUUID<T: Codable & Identifiable>(
        _ id: String,
        in array: inout [T],
        decode: T.Type,
        from data: Data,
        decoder: JSONDecoder
    ) where T.ID == UUID {
        guard let value = try? decoder.decode(T.self, from: data) else { return }
        if let index = array.firstIndex(where: { $0.id.uuidString == id }) {
            array[index] = value
        } else {
            array.append(value)
        }
    }
}

extension PersonalSimpleStudioEntityKind {
    var cloudKind: String { "simple.\(rawValue)" }

    init?(cloudKind: String) {
        guard cloudKind.hasPrefix("simple."), let raw = cloudKind.split(separator: ".").last else { return nil }
        self.init(rawValue: String(raw))
    }
}
