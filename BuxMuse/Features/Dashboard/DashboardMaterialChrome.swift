//
//  DashboardMaterialChrome.swift
//  BuxMuse
//
//  Dashboard pilot aliases — forwards to app-wide BuxMaterialChrome.
//

import SwiftUI

typealias DashboardMaterialCardVariant = BuxMaterialCardVariant
typealias DashboardMaterialChrome = BuxMaterialChrome
typealias DashboardMaterialCardChromeModifier = BuxMaterialCardChromeModifier

extension View {
    func dashboardMaterialCardChrome(
        _ variant: BuxMaterialCardVariant = .outlined,
        cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius
    ) -> some View {
        buxMaterialCardChrome(variant, cornerRadius: cornerRadius)
    }

    func dashboardMaterialPillCardLabel(
        cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius
    ) -> some View {
        buxMaterialPillCardLabel(cornerRadius: cornerRadius)
    }

    func dashboardMaterialPillAuxCardLabel(
        cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius
    ) -> some View {
        buxMaterialPillAuxCardLabel(cornerRadius: cornerRadius)
    }
}
