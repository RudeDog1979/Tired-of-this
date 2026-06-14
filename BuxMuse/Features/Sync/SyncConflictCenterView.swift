//
//  SyncConflictCenterView.swift
//  BuxMuse
//

import SwiftUI

struct SyncConflictCenterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var conflictStore = PersonalSyncConflictStore.shared

    private var locale: Locale { appSettingsManager.interfaceLocale }
    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    var body: some View {
        BuxThemedCardForm {
            if unresolvedConflicts.isEmpty {
                BuxFormSection {
                    BuxCatalogDynamicText(key: "No sync conflicts. Your iPhone and iPad data matches.")
                        .font(.system(size: 14, weight: .medium))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                }
            } else {
                BuxFormSection(title: "Review conflicts") {
                    ForEach(unresolvedConflicts) { conflict in
                        VStack(alignment: .leading, spacing: 10) {
                            BuxCatalogText.text(conflict.titleKey)
                                .font(.system(size: 15, weight: .bold))
                            Text(conflict.localSummary)
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                            HStack(spacing: 10) {
                                Button {
                                    conflictStore.resolve(conflict.id, preferLocal: true)
                                } label: {
                                    BuxCatalogText.text("Keep this device")
                                        .font(.system(size: 13, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(accent)

                                Button {
                                    conflictStore.resolve(conflict.id, preferLocal: false)
                                } label: {
                                    BuxCatalogText.text("Keep iCloud")
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                        BuxFormRowDivider()
                    }
                }
            }
        }
        .buxCatalogNavigationTitle("Sync conflicts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var unresolvedConflicts: [PersonalSyncConflict] {
        conflictStore.conflicts.filter { !$0.isResolved }
    }
}
