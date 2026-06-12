//
//  BuxPadBusinessCardHost.swift
//  BuxMuse — iPad Business Card Studio host (container metrics).
//

import SwiftUI

struct BuxPadBusinessCardHost: View {
    var body: some View {
        ProBusinessCardStudioView()
            .buxPadBusinessCardUIScreenMitigation()
            .buxPadPublishesSceneScale()
            .buxPadTabHostChrome()
            .buxPadReportsContainerMetrics()
    }
}
