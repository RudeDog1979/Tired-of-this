//
//  PersonalCloudSyncSettingsView.swift
//  BuxMuse
//  Features/Sync/
//
//  Toggle and status for personal iCloud sync (same Apple ID).
//

import SwiftUI

struct PersonalCloudSyncSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var debtEngine: DebtEngine
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var syncEngine = PersonalCloudSyncEngine.shared

    @State private var isWorking = false
    @State private var actionError: String?
    @State private var showEnableDisclaimer = false

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        BuxThemedCardForm {
            if store.personalCloudSyncEnabled {
                BuxFormSection {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.icloud.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accent)
                        BuxCatalogDynamicText(
                            key: "iCloud sync is active. Your data is stored in your private iCloud account with Apple — not on BuxMuse servers. BuxMuse cannot access, read, or view it."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Sync with iCloud") {
                Toggle(isOn: Binding(
                    get: { store.personalCloudSyncEnabled },
                    set: { newValue in
                        if newValue {
                            showEnableDisclaimer = true
                        } else {
                            Task { await toggleSync(false) }
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogDynamicText(key: "Sync with iCloud")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Expenses, debts, goals, and settings — syncs automatically across your devices")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isWorking)
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Status") {
                HStack(spacing: 10) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.system(size: 15, weight: .semibold))
                        Text(statusSubtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.personalCloudSyncEnabled {
                        Button {
                            Task { await syncNow() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isWorking)
                    }
                }
                .buxFormFieldPadding()

                if syncEngine.pendingConflictCount > 0 {
                    BuxFormRowDivider()
                    NavigationLink {
                        SyncConflictCenterView()
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                    } label: {
                        HStack {
                            BuxCatalogDynamicText(key: "Review sync conflicts")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text("\(syncEngine.pendingConflictCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accent)
                        }
                    }
                    .buxFormFieldPadding()
                }

                if let actionError {
                    BuxFormRowDivider()
                    Text(actionError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .buxFormFieldPadding()
                }
            }

            BuxFormSection {
                BuxCatalogDynamicText(key: "When iCloud sync is on, your data is stored with Apple — not on BuxMuse servers. BuxMuse cannot access or view it. Household sharing is separate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buxFormFieldPadding()
            }
        }
        .buxCatalogNavigationTitle("Sync with iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            BuxCatalogLabel.string("Turn on iCloud sync?", locale: locale),
            isPresented: $showEnableDisclaimer
        ) {
            Button(BuxCatalogLabel.string("Cancel", locale: locale), role: .cancel) {}
            Button(BuxCatalogLabel.string("Turn On", locale: locale)) {
                Task { await toggleSync(true) }
            }
        } message: {
            Text(
                BuxCatalogLabel.string(
                    "Your expenses, debts, goals, and settings will be stored in your private iCloud account with Apple — not on BuxMuse servers. BuxMuse cannot access, read, or view this data. Only you can see it through your Apple ID.",
                    locale: locale
                )
            )
        }
        .task {
            syncEngine.attach(brain: brain, debtEngine: debtEngine, goalsEngine: brain.goalsEngine)
            syncEngine.refreshEnabledState()
        }
    }

    private var statusIcon: String {
        switch syncEngine.syncStatus {
        case .disabled: return "icloud.slash"
        case .noAccount: return "person.crop.circle.badge.exclamationmark"
        case .idle: return "icloud"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .lastSynced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }

    private var statusTitle: String {
        switch syncEngine.syncStatus {
        case .disabled:
            return BuxCatalogLabel.string("Off", locale: locale)
        case .noAccount:
            return BuxCatalogLabel.string("Sign in to iCloud", locale: locale)
        case .idle:
            return BuxCatalogLabel.string("Ready", locale: locale)
        case .syncing:
            return BuxCatalogLabel.string("Syncing…", locale: locale)
        case .lastSynced:
            return BuxCatalogLabel.string("Up to date", locale: locale)
        case .error:
            return BuxCatalogLabel.string("Sync issue", locale: locale)
        }
    }

    private var statusSubtitle: String {
        switch syncEngine.syncStatus {
        case .disabled:
            return BuxCatalogLabel.string("Turn on to sync automatically across your Apple devices.", locale: locale)
        case .noAccount:
            return BuxCatalogLabel.string("Open Settings and sign in to iCloud.", locale: locale)
        case .idle, .syncing:
            return BuxCatalogLabel.string("Syncs automatically across your Apple devices.", locale: locale)
        case .lastSynced(let date):
            return date.formatted(date: .abbreviated, time: .shortened)
        case .error(let message):
            return message
        }
    }

    private func toggleSync(_ enabled: Bool) async {
        isWorking = true
        actionError = nil
        defer { isWorking = false }
        await syncEngine.setEnabled(enabled)
        if case .error(let message) = syncEngine.syncStatus {
            actionError = message
        }
    }

    private func syncNow() async {
        isWorking = true
        actionError = nil
        defer { isWorking = false }
        await syncEngine.syncNow()
        if case .error(let message) = syncEngine.syncStatus {
            actionError = message
        }
    }
}
