//
//  PersonalSyncConflictStore.swift
//  BuxMuse
//

import Combine
import Foundation

@MainActor
final class PersonalSyncConflictStore: ObservableObject {
    static let shared = PersonalSyncConflictStore()

    @Published private(set) var conflicts: [PersonalSyncConflict] = []

    private let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Sync/personal_sync_conflicts.json")
    }()

    private init() {
        load()
    }

    var unresolvedCount: Int {
        conflicts.filter { !$0.isResolved }.count
    }

    func replaceAll(_ newConflicts: [PersonalSyncConflict]) {
        conflicts = newConflicts
        persist()
    }

    func append(_ conflict: PersonalSyncConflict) {
        guard !conflicts.contains(where: { $0.entityKey == conflict.entityKey && !$0.isResolved }) else { return }
        conflicts.append(conflict)
        persist()
    }

    func append(contentsOf newConflicts: [PersonalSyncConflict]) {
        for conflict in newConflicts {
            append(conflict)
        }
    }

    func resolve(_ conflictID: UUID, preferLocal: Bool) {
        guard let index = conflicts.firstIndex(where: { $0.id == conflictID }) else { return }
        conflicts[index].isResolved = true
        persist()
        _ = preferLocal
    }

    func clearResolved() {
        conflicts.removeAll { $0.isResolved }
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path),
              let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([PersonalSyncConflict].self, from: data) else {
            conflicts = []
            return
        }
        conflicts = decoded
    }

    private func persist() {
        let dir = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(conflicts) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }
}
