//
//  TaxStudioHeader.swift
//  BuxMuse
//
//  Tax studio — “Tax” + signature gradient S + “tudio” + PRO badge.
//

import SwiftUI

struct TaxStudioNavigationTitle: View {
    var style: Style = .large

    enum Style {
        case large
        case compact
    }

    var body: some View {
        StudioProProductScreenHeader(
            prefixKey: "Tax",
            style: style == .large ? .large : .compact
        )
    }
}
