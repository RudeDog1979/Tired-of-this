//
//  PersonalCloudSyncSettingsView.swift
//  BuxMuse
//  Features/Sync/
//
//  Toggle and status for personal iCloud sync (same Apple ID).
//

import SwiftUI

private enum PersonalCloudEnableSheetPhase: Equatable {
    case checkingICloud
    case chooseBackup(PersonalCloudBackupSummary)
    case syncing(String)
    case failed(String)
}

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
    @State private var showEnableSheet = false
    @State private var enableSheetPhase: PersonalCloudEnableSheetPhase = .checkingICloud

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
                .disabled(isWorking || showEnableSheet)
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
            Button(BuxCatalogLabel.string("Continue", locale: locale)) {
                openEnableSheet()
            }
        } message: {
            Text(
                BuxCatalogLabel.string(
                    "Your expenses, debts, goals, and settings will be stored in your private iCloud account with Apple — not on BuxMuse servers. BuxMuse cannot access, read, or view this data. Only you can see it through your Apple ID.",
                    locale: locale
                )
            )
        }
        .sheet(isPresented: $showEnableSheet) {
            PersonalCloudEnableSheet(
                phase: $enableSheetPhase,
                accent: accent,
                locale: locale,
                onRestore: { sourceDeviceId in
                    await completeEnable(preferLocalMerge: false, preferredSourceDeviceId: sourceDeviceId)
                },
                onUseThisDevice: { await completeEnable(preferLocalMerge: true) },
                onCancel: { showEnableSheet = false },
                onRetryProbe: { await probeCloudBackupForSheet() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(isEnableSheetBusy)
        }
        .task {
            syncEngine.attach(brain: brain, debtEngine: debtEngine, goalsEngine: brain.goalsEngine)
            syncEngine.refreshEnabledState()
        }
    }

    private var isEnableSheetBusy: Bool {
        switch enableSheetPhase {
        case .checkingICloud, .syncing:
            return true
        case .chooseBackup, .failed:
            return false
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
            return BuxDisplayDate.dateAndTime(from: date, locale: locale)
        case .error(let message):
            return message
        }
    }

    private func openEnableSheet() {
        enableSheetPhase = .checkingICloud
        showEnableSheet = true
        Task { await probeCloudBackupForSheet() }
    }

    private func probeCloudBackupForSheet() async {
        enableSheetPhase = .checkingICloud

        guard await syncEngine.ensureAccountAvailableForEnable() else {
            if case .noAccount = syncEngine.syncStatus {
                enableSheetPhase = .failed(
                    BuxCatalogLabel.string("Sign in to iCloud in Settings first.", locale: locale)
                )
            } else if case .error(let message) = syncEngine.syncStatus {
                enableSheetPhase = .failed(message)
            } else {
                enableSheetPhase = .failed(
                    BuxCatalogLabel.string("Could not reach iCloud.", locale: locale)
                )
            }
            return
        }

        let summary = await syncEngine.fetchCloudBackupSummary()
        if let summary, syncEngine.shouldOfferRestoreChoice(summary: summary) {
            enableSheetPhase = .chooseBackup(summary)
            return
        }

        enableSheetPhase = .syncing(
            BuxCatalogLabel.string("Turning on iCloud sync…", locale: locale)
        )
        await completeEnable(preferLocalMerge: false)
    }

    private func completeEnable(preferLocalMerge: Bool, preferredSourceDeviceId: String? = nil) async {
        enableSheetPhase = .syncing(
            preferLocalMerge
                ? BuxCatalogLabel.string("Syncing this device to iCloud…", locale: locale)
                : BuxCatalogLabel.string("Restoring from iCloud…", locale: locale)
        )
        isWorking = true
        actionError = nil
        defer { isWorking = false }

        await syncEngine.setEnabled(
            true,
            preferLocalMerge: preferLocalMerge,
            preferredRestoreSourceDeviceId: preferredSourceDeviceId
        )
        if case .error(let message) = syncEngine.syncStatus {
            enableSheetPhase = .failed(message)
            actionError = message
            return
        }

        if preferLocalMerge == false, store.personalCloudSyncEnabled == false {
            enableSheetPhase = .failed(
                BuxCatalogLabel.string("Could not restore from iCloud.", locale: locale)
            )
            return
        }

        showEnableSheet = false
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

// MARK: - Enable sheet

private struct PersonalCloudEnableSheet: View {
    @Binding var phase: PersonalCloudEnableSheetPhase
    let accent: Color
    let locale: Locale
    let onRestore: (String?) async -> Void
    let onUseThisDevice: () async -> Void
    let onCancel: () -> Void
    let onRetryProbe: () async -> Void

    @State private var selectedSourceDeviceId: String?

    private var currentDeviceId: String {
        PersonalSyncDeviceIdentity.currentDeviceId
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .checkingICloud:
                    checkingContent
                case .chooseBackup(let summary):
                    chooseBackupContent(summary)
                case .syncing(let message):
                    syncingContent(message)
                case .failed(let message):
                    failedContent(message)
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle(BuxCatalogLabel.string("iCloud Sync", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .syncing = phase {} else {
                        Button(BuxCatalogLabel.string("Cancel", locale: locale)) {
                            onCancel()
                        }
                    }
                }
            }
        }
    }

    private var checkingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(accent)
                BuxCatalogDynamicText(key: "Checking iCloud for your backup…")
                    .font(.system(size: 16, weight: .semibold))
            }
            BuxCatalogDynamicText(key: "This usually takes a few seconds.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chooseBackupContent(_ summary: PersonalCloudBackupSummary) -> some View {
        let peerDevices = summary.peerDevices(excludingDeviceId: currentDeviceId)
        let recommendedId = summary.recommendedSourceDeviceId
            ?? peerDevices.first?.deviceId
        let selectedId = selectedSourceDeviceId ?? recommendedId
        let selectedDevice = peerDevices.first { $0.deviceId == selectedId }

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                BuxCatalogDynamicText(key: "Shared iCloud backup found")
                    .font(.system(size: 20, weight: .bold))
                if let backupDate = summary.lastBackupAt.map({
                    BuxDisplayDate.dateAndTime(from: $0, locale: locale)
                }) {
                    Text(
                        BuxLocalizedString.format(
                            "Last updated %@",
                            locale: locale,
                            backupDate
                        )
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }

            BuxCatalogDynamicText(
                key: "This is one backup shared across your Apple devices — not separate copies. Choose which device this iPad should match."
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)

            if !peerDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogDynamicText(key: "Restore using settings from")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(peerDevices, id: \.deviceId) { device in
                        Button {
                            selectedSourceDeviceId = device.deviceId
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: deviceIcon(for: device.name))
                                    .foregroundStyle(accent)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.displayName(for: device))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(
                                        BuxLocalizedString.format(
                                            "Last active %@",
                                            locale: locale,
                                            BuxDisplayDate.dateAndTime(from: device.lastSeenAt, locale: locale)
                                        )
                                    )
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if device.deviceId == recommendedId {
                                    Text(BuxCatalogLabel.string("Recommended", locale: locale))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(accent.opacity(0.12), in: Capsule())
                                }
                                Image(systemName: device.deviceId == selectedId ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(device.deviceId == selectedId ? accent : .secondary)
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(device.deviceId == selectedId ? accent.opacity(0.08) : Color.clear)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(spacing: 10) {
                Button {
                    Task { await onRestore(selectedId) }
                } label: {
                    Text(restoreButtonTitle(summary: summary, selectedDevice: selectedDevice))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(false)

                Button {
                    Task { await onUseThisDevice() }
                } label: {
                    Text(BuxCatalogLabel.string("Use This iPad Instead", locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            if selectedSourceDeviceId == nil {
                selectedSourceDeviceId = recommendedId
            }
        }
    }

    private func restoreButtonTitle(
        summary: PersonalCloudBackupSummary,
        selectedDevice: PersonalSyncRegisteredDevice?
    ) -> String {
        if let selectedDevice {
            return BuxLocalizedString.format(
                "Restore and match %@",
                locale: locale,
                summary.displayName(for: selectedDevice)
            )
        }
        return BuxCatalogLabel.string("Restore from iCloud", locale: locale)
    }

    private func deviceIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("mac") { return "laptopcomputer" }
        return "iphone"
    }

    private func syncingContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(accent)
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
            }
            BuxCatalogDynamicText(key: "Downloading your data from iCloud. Keep the app open.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failedContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
            } icon: {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
            }
            Button {
                Task { await onRetryProbe() }
            } label: {
                Text(BuxCatalogLabel.string("Try Again", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
    }
}
