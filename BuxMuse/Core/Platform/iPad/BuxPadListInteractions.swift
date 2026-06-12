//
//  BuxPadListInteractions.swift
//  BuxMuse — iPad list hover, drag payload, arrow-key helpers.
//

import SwiftUI
import UniformTypeIdentifiers

enum BuxPadExpenseDragPayload {
    static let type = UTType.plainText
    static func encode(_ id: UUID) -> String { "buxmuse.expense.\(id.uuidString)" }
    static func decode(_ value: String) -> UUID? {
        let prefix = "buxmuse.expense."
        guard value.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }
}

extension View {
    /// iPad regular-width expense rows — hover + drag affordance.
    @ViewBuilder
    func buxPadExpenseRowInteractions(recordId: UUID, enabled: Bool) -> some View {
        if enabled {
            self
                .buxPadHoverable()
                .draggable(BuxPadExpenseDragPayload.encode(recordId))
        } else {
            self
        }
    }

    @ViewBuilder
    func buxPadListArrowNavigation(
        enabled: Bool,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        if enabled {
            self
                .onKeyPress(.upArrow) {
                    onPrevious()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    onNext()
                    return .handled
                }
        } else {
            self
        }
    }
}
