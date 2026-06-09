//
//  BuxPadTaxStudioHost.swift
//  BuxMuse — iPad Tax Studio tool host.
//

import SwiftUI

struct BuxPadTaxStudioHost: View {
    var body: some View {
        TaxStudioHubView()
            .buxPadTabHostChrome()
    }
}
