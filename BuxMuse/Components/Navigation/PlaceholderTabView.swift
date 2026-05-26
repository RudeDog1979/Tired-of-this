//
//  PlaceholderTabView.swift
//  BuxMuse
//  Components/Navigation/
//
//  A high-fidelity empty state / placeholder tab view.
//

import SwiftUI

struct PlaceholderTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(themeManager.current.accentColor)
            
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Text("BuxMuse custom component interface under development.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
