//
//  BuxPadHomeHost.swift
//  BuxMuse — iPad Home tab host (readable column + metrics).
//

import SwiftUI

struct BuxPadHomeHost: View {
    var transactionNamespace: Namespace.ID

    var body: some View {
        DashboardView(transactionNamespace: transactionNamespace)
            .buxPadDashboardUIScreenMitigation()
            .buxPadPublishesSceneScale()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadExternalDisplayMenu()
                }
            }
    }
}
