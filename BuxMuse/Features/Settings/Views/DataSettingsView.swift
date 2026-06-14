//
//  DataSettingsView.swift
//  BuxMuse
//
//  Data control console: local backups, full JSON exports, database purging.
//

import SwiftUI
import SwiftData

struct DataSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var persistence: PersistenceController
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator

    @ObservedObject private var store = SettingsStore.shared

    @State private var showResetDialog = false
    @State private var showICloudChoiceDialog = false
    @State private var showBackupBeforeCloudDeleteDialog = false
    @State private var showCloudDeleteFirstWarning = false
    @State private var showCloudDeleteFinalWarning = false
    @State private var showLocalFinalPurgeDialog = false
    @State private var showExportBeforeCloudDeleteSheet = false
    @State private var showSuccessAlert = false
    @State private var showCloudDeleteFailedAlert = false
    @State private var showLogoCacheClearedAlert = false
    @State private var purgeDeletedCloudData = false
    @State private var resetKeepsCloudBackup = false
    @State private var cloudDeleteErrorMessage = ""
    @State private var isPerformingPurge = false
    @State private var exportURL: URL? = nil
    @State private var storageBreakdown = BuxStorageBreakdown.empty
    @State private var photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection {
                BuxCatalogDynamicText(key: "BuxMuse works on your device. You enter your own transactions — we never connect to your bank. Export or back up anytime.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()
            }

            BackupRestoreSettingsView()

            BuxFormSection(title: "Photo access settings") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Photo library access")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Select how many photos BuxMuse can access in system settings.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .buxFormFieldPadding()

                BuxFormRowDivider()

                Button {
                    BusinessCardPhotoLibraryAccess.openSettings()
                } label: {
                    HStack {
                        Image(systemName: photoStatus == .limited ? "photo.badge.checkmark" : "photo.on.rectangle.angled")
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Text(
                            BuxLocalizedString.format(
                                "Photos: %@",
                                locale: appSettingsManager.interfaceLocale,
                                photoStatus.localizedLabel(locale: appSettingsManager.interfaceLocale)
                            )
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        BuxCatalogDynamicText(key: "Manage photo access")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Sandbox backup") {
                Toggle(isOn: $store.allowLocalBackups) {
                    Text(BuxCatalogLabel.string("Allow Local Backups", locale: appSettingsManager.interfaceLocale))
                }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()

                if store.allowLocalBackups {
                    BuxFormRowDivider()
                    Picker(selection: $store.autoBackupFrequency) {
                        ForEach(AutoBackupFrequency.allCases) { freq in
                            Text(freq.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(freq)
                        }
                    } label: {
                        Text(BuxCatalogLabel.string("Backup Frequency", locale: appSettingsManager.interfaceLocale))
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()

                    if store.autoBackupFrequency == .custom {
                        BuxFormRowDivider()
                        HStack {
                            Text(BuxCatalogLabel.string("Backup every", locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Stepper(value: Binding(
                                get: { store.customBackupIntervalDays },
                                set: { newValue in
                                    store.customBackupIntervalDays = max(1, min(30, newValue))
                                    store.save()
                                }
                            ), in: 1...30) {
                                Text("\(store.customBackupIntervalDays) ") + Text(BuxCatalogLabel.string(store.customBackupIntervalDays == 1 ? "day" : "days", locale: appSettingsManager.interfaceLocale))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            }
                        }
                        .buxFormFieldPadding()
                    }
                }
            }

            BuxFormSection(title: "Storage") {
                BuxCatalogDynamicText(key: "All sizes are calculated on this device. BuxMuse never uploads your files.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()

                storageRow(
                    "Receipts & scans",
                    BuxStorageAuditEngine.formattedByteCount(storageBreakdown.receiptsAndScansBytes),
                    detail: "\(storageBreakdown.receiptImageCount + storageBreakdown.scanImageCount) images"
                )
                BuxFormRowDivider()
                storageRow(
                    "Merchant logos",
                    BuxStorageAuditEngine.formattedByteCount(storageBreakdown.merchantLogosBytes)
                )
                BuxFormRowDivider()
                storageRow(
                    "Database",
                    BuxStorageAuditEngine.formattedByteCount(storageBreakdown.databaseBytes)
                )
                BuxFormRowDivider()
                storageRow(
                    "Silent backups",
                    BuxStorageAuditEngine.formattedByteCount(storageBreakdown.silentBackupsBytes)
                )
                BuxFormRowDivider()
                storageRow(
                    "Settings",
                    BuxStorageAuditEngine.formattedByteCount(storageBreakdown.settingsBytes)
                )
                BuxFormRowDivider()
                storageRow(
                    "Total (tracked)",
                    BuxStorageAuditEngine.formattedByteCount(storageBreakdown.totalBytes),
                    emphasized: true
                )

                BuxFormRowDivider()

                BuxCatalogDynamicText(
                    key: "Export invoices (PDF + PNG) and optional receipt photos from Studio → Tools → Backup invoices."
                )
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
                .buxFormFieldPadding()

                Button {
                    refreshStorageBreakdown()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        BuxCatalogDynamicText(key: "Refresh storage sizes")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Data Guard mode") {
                Toggle(isOn: $store.dataGuardModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Data Guard mode")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Blocks all outbound merchant logo requests. Renders local monogram avatars. Zero data cost when on prepaid mobile.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Merchant data") {
                BuxCatalogDynamicText(key: "Merchant icons use your on-device cache first. When online, BuxMuse may refresh them automatically. Your merchant choices are stored locally on this device.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Button {
                    LightweightLogoCache.shared.clearCacheSynchronously()
                    showLogoCacheClearedAlert = true
                    refreshStorageBreakdown()
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        BuxCatalogDynamicText(key: "Clear merchant logo cache")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Export compliance") {
                Toggle(isOn: $store.includeStudioDataInExports) {
                    Text(BuxCatalogLabel.string("Include Studio data", locale: appSettingsManager.interfaceLocale))
                }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Toggle(isOn: $store.includeAnalyticsInExports) {
                    Text(BuxCatalogLabel.string("Include local performance metadata", locale: appSettingsManager.interfaceLocale))
                }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()

                if let url = exportURL {
                    BuxFormRowDivider()
                    ShareLink(item: url) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                            BuxCatalogDynamicText(key: "Save JSON backup archive")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                } else {
                    BuxFormRowDivider()
                    Button(action: generateJSONDump) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            BuxCatalogDynamicText(key: "Compile JSON data export")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                }

                if let lastExport = store.lastExportDate {
                    BuxFormRowDivider()
                    HStack {
                        BuxCatalogDynamicText(key: "Last compiled")
                        Spacer()
                        Text(lastExport, style: .date)
                            .buxLabelSecondary()
                    }
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Delete data") {
                Button.buxDestructive("Delete All Local App Data") {
                    showResetDialog = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .buxFormFieldPadding()
            }
        }
        .buxCatalogNavigationTitle("Backup & restore")
        .navigationBarTitleDisplayMode(.inline)
        .alert(BuxCatalogLabel.string("Database Reset Complete", locale: appSettingsManager.interfaceLocale), isPresented: $showSuccessAlert) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            if purgeDeletedCloudData {
                BuxCatalogDynamicText(key: "Your BuxMuse database, settings, and iCloud backup have been erased. This device is restored to fresh seeds.")
            } else if resetKeepsCloudBackup {
                BuxCatalogDynamicText(key: "Your BuxMuse database and settings have been restored to fresh seeds. Expenses, Tax savings, merchants, Studio data, caches, and backups are removed. Your iCloud backup was kept.")
            } else {
                BuxCatalogDynamicText(key: "Your BuxMuse database and settings have been restored to fresh seeds. Expenses, Tax savings, merchants, Studio data, caches, and backups are removed from this device.")
            }
        }
        .alert(BuxCatalogLabel.string("iCloud deletion failed", locale: appSettingsManager.interfaceLocale), isPresented: $showCloudDeleteFailedAlert) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            Text(cloudDeleteErrorMessage)
        }
        .alert(BuxCatalogLabel.string("Logo cache cleared", locale: appSettingsManager.interfaceLocale), isPresented: $showLogoCacheClearedAlert) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "Merchant favicons will download again the next time you view them.")
        }
        .confirmationDialog(BuxCatalogLabel.string("WARNING: Delete All Data?", locale: appSettingsManager.interfaceLocale), isPresented: $showResetDialog, titleVisibility: .visible) {
            if store.personalCloudSyncEnabled {
                Button(BuxCatalogLabel.string("Continue to iCloud choice", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                    showICloudChoiceDialog = true
                }
            } else {
                Button(BuxCatalogLabel.string("Continue", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                    resetKeepsCloudBackup = false
                    purgeDeletedCloudData = false
                    showLocalFinalPurgeDialog = true
                }
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            if store.personalCloudSyncEnabled {
                BuxCatalogDynamicText(key: "This action is irreversible on this device. It will wipe expenses, goals, Tax savings, merchants, logo cache, Studio and Simple Studio records, receipts, scans, backups, and reset all settings. On the next step you choose whether to keep or delete your iCloud backup.")
            } else {
                BuxCatalogDynamicText(key: "This action is irreversible on this device. It will wipe expenses, goals, Tax savings, merchants, logo cache, Studio and Simple Studio records, receipts, scans, backups, and reset all settings.")
            }
        }
        .confirmationDialog(BuxCatalogLabel.string("What should happen to your iCloud data?", locale: appSettingsManager.interfaceLocale), isPresented: $showICloudChoiceDialog, titleVisibility: .visible) {
            Button(BuxCatalogLabel.string("Keep data in iCloud", locale: appSettingsManager.interfaceLocale)) {
                resetKeepsCloudBackup = true
                purgeDeletedCloudData = false
                showLocalFinalPurgeDialog = true
            }
            Button(BuxCatalogLabel.string("Also delete iCloud data", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                resetKeepsCloudBackup = false
                purgeDeletedCloudData = true
                showBackupBeforeCloudDeleteDialog = true
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "You can erase this device only and keep a backup in iCloud for your other devices, or permanently delete your BuxMuse iCloud backup on every device signed into this Apple ID.")
        }
        .confirmationDialog(BuxCatalogLabel.string("Back up before deleting iCloud", locale: appSettingsManager.interfaceLocale), isPresented: $showBackupBeforeCloudDeleteDialog, titleVisibility: .visible) {
            Button(BuxCatalogLabel.string("Export JSON backup", locale: appSettingsManager.interfaceLocale)) {
                generateJSONDump()
                showExportBeforeCloudDeleteSheet = true
            }
            Button(BuxCatalogLabel.string("Continue without backup", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                showCloudDeleteFirstWarning = true
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "Deleting iCloud data is permanent on all your devices. Save a local JSON backup first if you might need this data later.")
        }
        .alert(BuxCatalogLabel.string("Delete iCloud data?", locale: appSettingsManager.interfaceLocale), isPresented: $showCloudDeleteFirstWarning) {
            Button(BuxCatalogLabel.string("Yes, continue", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                showCloudDeleteFinalWarning = true
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "Are you sure? This will permanently remove your BuxMuse backup from iCloud on every device. You cannot recover it from Apple later.")
        }
        .alert(BuxCatalogLabel.string("Final warning: delete iCloud backup?", locale: appSettingsManager.interfaceLocale), isPresented: $showCloudDeleteFinalWarning) {
            Button(BuxCatalogLabel.string("Delete iCloud and reset device", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                performFullPurge(deleteCloudData: true)
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "Last chance. BuxMuse will erase your iCloud backup and all local data on this device. Other devices will no longer restore from iCloud. Are you absolutely sure?")
        }
        .alert(BuxCatalogLabel.string("Final warning: erase everything?", locale: appSettingsManager.interfaceLocale), isPresented: $showLocalFinalPurgeDialog) {
            Button(BuxCatalogLabel.string("Erase everything permanently", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                performFullPurge(deleteCloudData: false)
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            if resetKeepsCloudBackup {
                BuxCatalogDynamicText(key: "Last chance: BuxMuse will permanently delete every piece of local data on this device. Your iCloud backup will be kept. Are you absolutely sure?")
            } else {
                BuxCatalogDynamicText(key: "Last chance: BuxMuse will permanently delete every piece of local data on this device. Are you absolutely sure?")
            }
        }
        .sheet(isPresented: $showExportBeforeCloudDeleteSheet) {
            exportBeforeCloudDeleteSheet
        }
        .onChange(of: store.allowLocalBackups) { _, _ in store.save() }
        .onChange(of: store.autoBackupFrequency) { _, _ in store.save() }
        .onChange(of: store.includeStudioDataInExports) { _, _ in store.save() }
        .onChange(of: store.includeAnalyticsInExports) { _, _ in store.save() }
        .onAppear {
            photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()
            refreshStorageBreakdown()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()
        }
    }

    // MARK: - Storage

    private func storageRow(_ label: String, _ value: String, detail: String? = nil, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            BuxCatalogDynamicText(key: label)
                .font(.system(size: 15, weight: emphasized ? .bold : .semibold))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: emphasized ? .bold : .semibold, design: .rounded))
                    .foregroundColor(emphasized ? themeManager.current.accentColor : themeManager.labelPrimary(for: colorScheme))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }
        }
        .buxFormFieldPadding()
    }

    private func refreshStorageBreakdown() {
        storageBreakdown = BuxStorageAuditEngine.audit()
    }

    // MARK: - Export Logic

    private func generateJSONDump() {
        do {
            let expenses = (try? persistence.fetchAllExpenseEntities()) ?? []
            let goals = (try? persistence.fetchAllGoalEntities()) ?? []

            var payload: [String: Any] = [
                "buxmuse_app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                "export_timestamp": Date().timeIntervalSince1970,
                "expenses_count": expenses.count,
                "goals_count": goals.count
            ]

            if store.includeAnalyticsInExports {
                payload["performance_metadata"] = [
                    "platform": "iOS",
                    "backup_kind": "manual_export",
                    "studio_mode": store.studioMode.rawValue,
                    "budgeting_mode": store.budgetingMode.rawValue
                ]
            }

            var expenseList = [[String: Any]]()
            for exp in expenses {
                expenseList.append([
                    "id": exp.id.uuidString,
                    "name": exp.name,
                    "amount": exp.amountValue.description,
                    "currency": exp.currencyCode,
                    "category": exp.categoryRaw,
                    "date": exp.date.timeIntervalSince1970,
                    "notes": exp.notes ?? ""
                ])
            }
            payload["expenses"] = expenseList

            var goalList = [[String: Any]]()
            for goal in goals {
                goalList.append([
                    "id": goal.id.uuidString,
                    "name": goal.name,
                    "target": goal.targetAmount.description,
                    "current": goal.currentAmount.description,
                    "deadline": goal.deadline?.timeIntervalSince1970 ?? 0
                ])
            }
            payload["goals"] = goalList

            if store.includeStudioDataInExports {
                let snapshot = studioStore.currentSnapshot()
                if let data = try? JSONEncoder().encode(snapshot),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    payload["freelance"] = json
                }
                let simpleSnapshot = simpleStudioStore.snapshot
                if let data = try? JSONEncoder().encode(simpleSnapshot),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    payload["simple_studio"] = json
                }
            }

            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("buxmuse_data_backup.json")
            try data.write(to: fileURL, options: .atomic)

            self.exportURL = fileURL
            self.store.lastExportDate = Date()
            self.store.save()
        } catch {
            print("Failed to generate JSON dump: \(error)")
        }
    }

    // MARK: - Destruction Logic

    private var exportBeforeCloudDeleteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                BuxCatalogDynamicText(key: "Save this JSON file somewhere safe — Files, iCloud Drive, or email — before deleting your iCloud backup.")
                    .font(.system(size: 14, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                if let url = exportURL {
                    ShareLink(item: url) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                            BuxCatalogDynamicText(key: "Save JSON backup archive")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                }

                Button(role: .destructive) {
                    showExportBeforeCloudDeleteSheet = false
                    showCloudDeleteFirstWarning = true
                } label: {
                    BuxCatalogDynamicText(key: "Continue to iCloud deletion")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .buxCatalogNavigationTitle("Save local backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) {
                        showExportBeforeCloudDeleteSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func performFullPurge(deleteCloudData: Bool) {
        guard !isPerformingPurge else { return }
        isPerformingPurge = true
        purgeDeletedCloudData = deleteCloudData

        Task {
            if deleteCloudData {
                do {
                    try await PersonalCloudSyncEngine.shared.deleteAllCloudData()
                } catch {
                    await MainActor.run {
                        cloudDeleteErrorMessage = error.localizedDescription
                        showCloudDeleteFailedAlert = true
                        isPerformingPurge = false
                    }
                    return
                }
            } else {
                PersonalCloudSyncEngine.shared.prepareForFactoryReset()
            }

            await MainActor.run {
                finishLocalPurge(restoreFromCloudOnNextSync: resetKeepsCloudBackup)
                isPerformingPurge = false
            }
        }
    }

    private func finishLocalPurge(restoreFromCloudOnNextSync: Bool) {
        BuxStorageAuditEngine.performNuclearLocalWipe()

        do {
            try persistence.recreateLocalStoreForFactoryReset()
        } catch {
            print("Database purge failed: \(error)")
        }

        store.resetAllData()
        studioStore.purgeAllPersistedData()
        simpleStudioStore.resetAllData()
        HustleManager.shared.resetAllData()
        MoneyMapLayoutStore.shared.resetAll()
        BuxNotificationInboxEngine.purgePersistedState()
        StudioTimerController.shared.reset()
        PersonalSyncConflictStore.shared.clearAll()
        tutorialCoordinator.tearDownForFactoryReset()
        LightweightLogoCache.shared.clearCacheSynchronously()
        SimpleStudioScanImageStore.purgeAllStoredImages()
        TaxTranslationCache.clearAll()
        exportURL = nil

        appSettingsManager.applyRegionalPreferences(from: store)
        themeManager.restoreGlobalAppearance()
        brain.refreshExpenses()
        taxEnvelopeBrain.refreshAll()
        refreshStorageBreakdown()

        if restoreFromCloudOnNextSync {
            PersonalCloudSyncEngine.markPendingCloudRestoreAfterLocalWipe()
        }

        NotificationCenter.default.post(name: .buxMuseDidPerformFactoryReset, object: nil)
        showSuccessAlert = true
    }
}
