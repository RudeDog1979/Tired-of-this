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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @ObservedObject private var store = SettingsStore.shared

    @State private var showResetDialog = false
    @State private var showSuccessAlert = false
    @State private var showLogoCacheClearedAlert = false
    @State private var exportURL: URL? = nil
    @State private var photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()

    var body: some View {
        BuxThemedCardForm {
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
                            .foregroundColor(themeManager.current.accentColor)
                        Text(
                            BuxLocalizedString.format(
                                "Photos: %@",
                                locale: BuxInterfaceLocale.currentInterfaceLocale,
                                photoStatus.label
                            )
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        BuxCatalogDynamicText(key: "Manage photo access")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.current.accentColor)
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Sandbox backup") {
                Toggle(isOn: $store.allowLocalBackups) {
                    Text(BuxCatalogLabel.string("Allow Local Backups", locale: appSettingsManager.interfaceLocale))
                }
                    .tint(themeManager.current.accentColor)
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
                    .tint(themeManager.current.accentColor)
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
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                        }
                        .buxFormFieldPadding()
                    }
                }
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
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Merchant data") {
                BuxCatalogDynamicText(key: "Merchant icons use your on-device cache first. When online, BuxMuse may fetch favicons from Google or DuckDuckGo. Your merchant choices are stored locally on this device.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Button {
                    LightweightLogoCache.shared.clearCacheSynchronously()
                    showLogoCacheClearedAlert = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        BuxCatalogDynamicText(key: "Clear merchant logo cache")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Export compliance") {
                Toggle(isOn: $store.includeStudioDataInExports) {
                    Text(BuxCatalogLabel.string("Include Studio data", locale: appSettingsManager.interfaceLocale))
                }
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Toggle(isOn: $store.includeAnalyticsInExports) {
                    Text(BuxCatalogLabel.string("Include local performance metadata", locale: appSettingsManager.interfaceLocale))
                }
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()

                if let url = exportURL {
                    BuxFormRowDivider()
                    ShareLink(item: url) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                            BuxCatalogDynamicText(key: "Save JSON backup archive")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
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
                        .foregroundColor(themeManager.current.accentColor)
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
            BuxCatalogDynamicText(key: "Your BuxMuse database and settings have been restored to fresh seeds. Expenses, merchants, and cached logos are removed.")
        }
        .alert(BuxCatalogLabel.string("Logo cache cleared", locale: appSettingsManager.interfaceLocale), isPresented: $showLogoCacheClearedAlert) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "Merchant favicons will download again the next time you view them.")
        }
        .confirmationDialog(BuxCatalogLabel.string("WARNING: Delete All Data?", locale: appSettingsManager.interfaceLocale), isPresented: $showResetDialog, titleVisibility: .visible) {
            Button(BuxCatalogLabel.string("Confirm Complete Purge", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                performFullPurge()
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "This action is completely offline and irreversible. It will wipe all expenses, merchants, logo cache, Studio records, secure passcodes, and reset settings.")
        }
        .onChange(of: store.allowLocalBackups) { _, _ in store.save() }
        .onChange(of: store.autoBackupFrequency) { _, _ in store.save() }
        .onChange(of: store.includeStudioDataInExports) { _, _ in store.save() }
        .onChange(of: store.includeAnalyticsInExports) { _, _ in store.save() }
        .onAppear {
            photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()
        }
    }

    // MARK: - Export Logic

    private func generateJSONDump() {
        do {
            let expenses = (try? persistence.fetchAllExpenseEntities()) ?? []
            let goals = (try? persistence.fetchAllGoalEntities()) ?? []

            var payload: [String: Any] = [
                "buxmuse_app_version": "1.0.0",
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

    private func performFullPurge() {
        store.resetAllData()
        LightweightLogoCache.shared.clearCacheSynchronously()

        do {
            try persistence.purgeAllUserFinancialData()
            try persistence.seedExpenseCatalogIfNeeded()
            studioStore.resetAllData()
            simpleStudioStore.resetAllData()
            brain.refreshExpenses()
            self.showSuccessAlert = true
        } catch {
            print("Database purge failed: \(error)")
        }
    }
}
