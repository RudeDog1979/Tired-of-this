//
//  HustleSelectorBar.swift
//  BuxMuse
//
//  Core/DesignSystem/
//  A premium, high-contrast, scrollable horizontal workspace gig selector bar.
//

import SwiftUI

public struct HustleSelectorBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var hustleManager = HustleManager.shared
    @ObservedObject private var store = SettingsStore.shared
    
    public init() {}
    
    public var body: some View {
        if store.sideHustleMatrixEnabled {
            VStack(alignment: .leading, spacing: 6) {
                if let label = HustleWorkspaceFilter.activeWorkspaceLabel() {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(
                            BuxLocalizedString.format(
                                "Viewing: %@",
                                locale: appSettingsManager.interfaceLocale,
                                label
                            )
                        )
                            .font(.system(size: 12, weight: .semibold))
                        if store.showUnassignedExpensesInWorkspace {
                            BuxCatalogDynamicText(key: "· includes unassigned")
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.75)
                        }
                    }
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        hustlePill(title: "All Workspaces", id: nil, colorHex: "#5A55F5")

                        ForEach(hustleManager.hustles.filter { $0.isActive }) { hustle in
                            hustlePill(
                                title: hustle.name,
                                id: hustle.id,
                                colorHex: hustle.colorHex
                            )
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.vertical, 8)
                }
                .buxScrollDismissesKeyboard()
            }
        }
    }
    
    private func hustlePill(title: String, id: UUID?, colorHex: String) -> some View {
        let isSelected = hustleManager.selectedHustleId == id
        let accentColor = Color(hex: colorHex)
        let isSolar = store.solarContrastModeEnabled
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                hustleManager.selectHustle(id)
            }
        }) {
            HStack(spacing: 6) {
                if id != nil {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                
                BuxCatalogText.text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
            }
            .foregroundColor(pillForegroundColor(isSelected: isSelected, isSolar: isSolar, selectedColor: accentColor))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                pillBackgroundView(isSelected: isSelected, isSolar: isSolar, selectedColor: accentColor)
            }
            .clipShape(Capsule())
            .overlay {
                pillBorderOverlay(isSelected: isSelected, isSolar: isSolar, selectedColor: accentColor)
            }
            .shadow(
                color: isSelected && !isSolar ? accentColor.opacity(0.25) : .clear,
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }
    
    private func pillForegroundColor(isSelected: Bool, isSolar: Bool, selectedColor: Color) -> Color {
        if isSolar {
            return isSelected ? .white : .black
        }
        if isSelected {
            return .white
        } else {
            return themeManager.labelPrimary(for: colorScheme)
        }
    }
    
    @ViewBuilder
    private func pillBackgroundView(isSelected: Bool, isSolar: Bool, selectedColor: Color) -> some View {
        if isSolar {
            if isSelected {
                Color.black
            } else {
                Color.white
            }
        } else {
            if isSelected {
                selectedColor
            } else {
                themeManager.cardFill(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.35 : 0.6)
            }
        }
    }
    
    @ViewBuilder
    private func pillBorderOverlay(isSelected: Bool, isSolar: Bool, selectedColor: Color) -> some View {
        if isSolar {
            Capsule()
                .strokeBorder(Color.black, lineWidth: isSelected ? 2.5 : 2.0)
        } else {
            if !isSelected {
                Capsule()
                    .strokeBorder(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
            } else {
                EmptyView()
            }
        }
    }
}
