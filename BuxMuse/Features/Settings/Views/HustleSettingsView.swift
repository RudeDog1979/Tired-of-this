//
//  HustleSettingsView.swift
//  BuxMuse
//
//  Features/Settings/Views/
//  Advanced console for managing Side-Hustles (Multi-Gig Ledger).
//

import SwiftUI

struct HustleSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var hustleManager = HustleManager.shared
    @ObservedObject private var store = SettingsStore.shared
    
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    
    @State private var newHustleName = ""
    @State private var selectedColorHex = "#9C27B0"
    @State private var isCreating = false
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?
    @State private var editingHustle: Hustle?
    
    // Premium color options
    private let premiumColors = [
        "#9C27B0", // Deep Purple
        "#00E5FF", // Neon Cyan
        "#30D158", // Emerald Green
        "#FF5E5B", // Sunset Coral
        "#FF9F0A", // Amber Gold
        "#5A55F5"  // Electric Indigo
    ]
    
    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Workspace mode") {
                Toggle(isOn: $store.sideHustleMatrixEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Enable workspace switching")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Optional for solo operators and teams. Keeps personal and business ledgers separate when you need it — off by default.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
                .onChange(of: store.sideHustleMatrixEnabled) { _, enabled in
                    if enabled, hustleManager.hustles.isEmpty {
                        _ = hustleManager.ensureDefaultWorkspaceIfNeeded()
                    }
                    themeManager.updateThemeForActiveWorkspace()
                }
            }

            if store.sideHustleMatrixEnabled {
                BuxFormSection(title: "Unassigned expenses") {
                    Toggle(isOn: $store.showUnassignedExpensesInWorkspace) {
                        VStack(alignment: .leading, spacing: 3) {
                            BuxCatalogDynamicText(key: "Show unassigned when filtering")
                                .font(.system(size: 15, weight: .semibold))
                            BuxCatalogDynamicText(key: "When a workspace is selected, expenses without a workspace tag appear with an Unassigned badge.")
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }

                hustleWorkspaceTierBanner

                // Section 2: Manage Active Hustles
                BuxFormSection(title: "Your active workspaces") {
                if hustleManager.hustles.isEmpty {
                    BuxCatalogDynamicText(key: "No workspaces found. Tap below to create your first business gig.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                } else {
                    ForEach(hustlesList) { hustle in
                        hustleRow(hustle)
                        if hustle.id != hustleManager.hustles.last?.id {
                            BuxFormRowDivider()
                        }
                    }
                }
            }
            
            // Section 3: Create a workspace (or Upgrade warning if limit reached)
            if hustleManager.canAddHustle() {
                BuxFormSection(title: "Add a new gig workspace") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField(BuxCatalogLabel.string("Workspace Name (e.g. Design Studio, Consulting)", locale: appSettingsManager.interfaceLocale), text: $newHustleName)
                            .font(.system(size: 15, weight: .semibold))
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .textFieldStyle(.plain)
                        
                        Divider().opacity(0.1)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BuxCatalogDynamicText(key: "Brand color")
                                .font(.system(size: 12, weight: .bold))
                                .buxLabelSecondary()
                            
                            HStack(spacing: 12) {
                                ForEach(premiumColors, id: \.self) { colorHex in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                            selectedColorHex = colorHex
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: colorHex))
                                                .frame(width: 28, height: 28)
                                            
                                            if selectedColorHex == colorHex {
                                                Circle()
                                                    .strokeBorder(Color.white, lineWidth: 2)
                                                    .frame(width: 20, height: 20)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Button(action: createNewWorkspace) {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                BuxCatalogDynamicText(key: "Create workspace")
                                Spacer()
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(newHustleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : themeManager.current.accentColor)
                            )
                        }
                        .disabled(newHustleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .buxFormFieldPadding()
                }
            } else {
                freeTierUpgradeBanner
            }
            }
        }
        .buxCatalogNavigationTitle("Workspaces")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
        .sheet(item: $proUpsellFeature) { feature in
            StudioProUpsellSheet(feature: feature)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(studioStore)
                .environmentObject(simpleStudioStore)
        }
        .sheet(item: $editingHustle) { hustle in
            WorkspaceDetailEditorSheet(hustle: hustle) { updated in
                hustleManager.updateHustle(updated)
                if hustleManager.selectedHustleId == updated.id {
                    themeManager.updateThemeForActiveWorkspace()
                }
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
        }
    }
    
    // Sort hustles: active gig context first
    private var hustlesList: [Hustle] {
        hustleManager.hustles
    }
    
    // Render individual hustle row
    private func hustleRow(_ hustle: Hustle) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: hustle.colorHex))
                .frame(width: 14, height: 14)
                .overlay {
                    if hustleManager.selectedHustleId == hustle.id {
                        Circle()
                            .stroke(themeManager.current.accentColor, lineWidth: 2)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hustle.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                
                if hustleManager.selectedHustleId == hustle.id {
                    BuxCatalogDynamicText(key: "Current active ledger context")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                } else {
                    Text(BuxCatalogLabel.string(hustle.isActive ? "Active" : "Archived", locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    editingHustle = hustle
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(BuxCatalogLabel.string("Edit workspace", locale: appSettingsManager.interfaceLocale))

                if hustleManager.selectedHustleId != hustle.id {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            hustleManager.selectHustle(hustle.id)
                        }
                    }) {
                        BuxCatalogDynamicText(key: "Select")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(themeManager.current.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        .font(.system(size: 18))
                }
                
                // Allow deleting only if there is more than 1 hustle
                if hustleManager.hustles.count > 1 {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            hustleManager.deleteHustle(id: hustle.id)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buxFormFieldPadding()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingHustle = hustle
        }
    }
    
    private var hustleWorkspaceTierBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "briefcase.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    BuxCatalogDynamicText(key: "Gig spaces")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    if store.studioMode == .pro {
                        ProFeatureBadge(compact: true)
                    } else {
                        Text(BuxCatalogLabel.string("FREE", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Text(BuxCatalogLabel.string(store.studioMode == .pro ? "Unlimited multi-gig workspaces unlocked" : "Active workspace ledger cap: 3 gigs", locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
            }
            
            Spacer()
        }
        .padding(BuxLayout.section)
        .buxFormSectionCard()
    }
    
    private var freeTierUpgradeBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
                
                BuxCatalogDynamicText(key: "Upgrade to Pro Studio")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
            
            BuxCatalogDynamicText(key: "You've hit the active side-gig limit for Simple Studio. Upgrade to Pro Studio to unlock unlimited ledgers, business card design, automatic invoice generation, and full revenue forecasting.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {
                proUpsellFeature = .hustleUnlimited
            }) {
                HStack {
                    Spacer()
                    BuxCatalogDynamicText(key: "Unlock Pro Studio Matrix")
                    Spacer()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [themeManager.current.accentColor, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(BuxLayout.section)
        .buxFormSectionCard()
    }
    
    private func createNewWorkspace() {
        let name = newHustleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let success = hustleManager.addHustle(name: name, colorHex: selectedColorHex)
        if success {
            newHustleName = ""
            selectedColorHex = premiumColors.randomElement() ?? "#9C27B0"
        }
    }
}
