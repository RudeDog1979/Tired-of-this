//
//  BuxPadStudioDragDrop.swift
//  BuxMuse — iPad drag payloads + drop targets (expenses, invoices, receipts).
//

import SwiftUI
import UniformTypeIdentifiers

enum BuxPadInvoiceDragPayload {
    static let type = UTType.plainText
    static func encode(_ id: UUID) -> String { "buxmuse.invoice.\(id.uuidString)" }
    static func decode(_ value: String) -> UUID? {
        let prefix = "buxmuse.invoice."
        guard value.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }
}

enum BuxPadReceiptDragPayload {
    static let type = UTType.plainText
    static func encode(_ id: UUID) -> String { "buxmuse.receipt.\(id.uuidString)" }
    static func decode(_ value: String) -> UUID? {
        let prefix = "buxmuse.receipt."
        guard value.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }
}

enum BuxPadStudioDropRouter {
    @MainActor
    static func handle(
        payloads: [String],
        destination: BuxPadStudioDestination,
        padBrain: BuxPadNavigationBrain,
        navigation: NavigationCoordinator
    ) -> Bool {
        guard BuxPadIdiom.isPad else { return false }
        for payload in payloads {
            if let expenseId = BuxPadExpenseDragPayload.decode(payload) {
                padBrain.selectedExpenseId = expenseId
                padBrain.selectedStudioDestination = destination.rawValue
                navigation.selectedTab = .studio
                return true
            }
            if let invoiceId = BuxPadInvoiceDragPayload.decode(payload) {
                padBrain.selectedStudioDestination = BuxPadStudioDestination.invoices.rawValue
                padBrain.externalInvoiceTargetId = invoiceId
                navigation.selectedTab = .studio
                return true
            }
            if let receiptId = BuxPadReceiptDragPayload.decode(payload) {
                padBrain.selectedStudioDestination = BuxPadStudioDestination.receipts.rawValue
                navigation.selectedTab = .studio
                _ = receiptId
                return true
            }
        }
        return false
    }
}

extension View {
    @ViewBuilder
    func buxPadDraggableInvoice(id: UUID, enabled: Bool) -> some View {
        if enabled {
            self.draggable(BuxPadInvoiceDragPayload.encode(id))
        } else {
            self
        }
    }

    @ViewBuilder
    func buxPadDraggableReceipt(id: UUID, enabled: Bool) -> some View {
        if enabled {
            self.draggable(BuxPadReceiptDragPayload.encode(id))
        } else {
            self
        }
    }

    @ViewBuilder
    func buxPadStudioDropDestination(
        destination: BuxPadStudioDestination,
        enabled: Bool = BuxPadIdiom.isPad
    ) -> some View {
        if enabled {
            self.modifier(BuxPadStudioDropDestinationModifier(destination: destination))
        } else {
            self
        }
    }
}

private struct BuxPadStudioDropDestinationModifier: ViewModifier {
    let destination: BuxPadStudioDestination
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var navigation: NavigationCoordinator

    func body(content: Content) -> some View {
        content
            .dropDestination(for: String.self) { items, _ in
                BuxPadStudioDropRouter.handle(
                    payloads: items,
                    destination: destination,
                    padBrain: padBrain,
                    navigation: navigation
                )
            } isTargeted: { targeted in
                if targeted {
                    padBrain.isInspectorColumnVisible = true
                }
            }
    }
}
