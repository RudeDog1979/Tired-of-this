//
//  BuxPadInvoiceDesignerHost.swift
//  BuxMuse — iPad Invoice Designer split host (generalizes existing split pattern).
//

import SwiftUI

struct BuxPadInvoiceDesignerHost<Designer: View>: View {
    @ViewBuilder var designer: () -> Designer

    var body: some View {
        designer()
            .buxPadPublishesSceneScale()
            .buxPadReportsContainerMetrics()
    }
}
