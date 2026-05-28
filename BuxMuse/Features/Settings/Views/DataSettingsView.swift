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
    @EnvironmentObject private var studioStore: StudioStore
    
    @ObservedObject private var store = SettingsStore.shared
    
    @State private var showResetDialog = false
    @State private var showSuccessAlert = false
    @State private var exportURL: URL? = nil
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            BuxHeroMeshBackground()

            Form {
                Section("SANDBOX BACKUP") {
                    Toggle("Allow Local Backups", isOn: $store.allowLocalBackups)
                    
                    if store.allowLocalBackups {
                        Picker("Backup Frequency", selection: $store.autoBackupFrequency) {
                            ForEach(AutoBackupFrequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("MERCHANT DATA") {
                    Text("Merchant icons use your on-device cache first. When online, BuxMuse may fetch favicons from Google or DuckDuckGo. Your merchant choices are stored locally on this device.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("EXPORT COMPLIANCE") {
                    Toggle("Include Studio Data", isOn: $store.includeStudioDataInExports)
                    Toggle("Include Local Performance Metadata", isOn: $store.includeAnalyticsInExports)
                    
                    if let url = exportURL {
                        ShareLink(item: url) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("Save JSON Backup Archive")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.current.accentColor)
                        }
                    } else {
                        Button(action: generateJSONDump) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Compile JSON Data Export")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.current.accentColor)
                        }
                    }
                    
                    if let lastExport = store.lastExportDate {
                        HStack {
                            Text("Last Compiled")
                            Spacer()
                            Text(lastExport, style: .date)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section("DESTRUCTION ZONE") {
                    Button(action: { showResetDialog = true }) {
                        Text("Delete All Local App Data")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Data Control")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Database Reset Complete", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your BuxMuse database and settings have been restored to fresh seeds. All private database entries are deleted.")
        }
        .confirmationDialog("WARNING: Delete All Data?", isPresented: $showResetDialog, titleVisibility: .visible) {
            Button("Confirm Complete Purge", role: .destructive) {
                performFullPurge()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is completely offline and irreversible. It will wipe all expenses, Studio records, secure passcodes, and reset everything.")
        }
        .onChange(of: store.allowLocalBackups) { _, _ in store.save() }
        .onChange(of: store.autoBackupFrequency) { _, _ in store.save() }
        .onChange(of: store.includeStudioDataInExports) { _, _ in store.save() }
        .onChange(of: store.includeAnalyticsInExports) { _, _ in store.save() }
    }
    
    // MARK: - Export Logic
    
    private func generateJSONDump() {
        do {
            // Read expenses, goals, and freelance state
            let expenses = (try? persistence.fetchAllExpenseEntities()) ?? []
            let goals = (try? persistence.fetchAllGoalEntities()) ?? []
            
            var payload: [String: Any] = [
                "buxmuse_app_version": "1.0.0",
                "export_timestamp": Date().timeIntervalSince1970,
                "expenses_count": expenses.count,
                "goals_count": goals.count
            ]
            
            // Format expenses simply
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
            
            // Format goals
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
            
            // Format freelance profile if requested
            if store.includeStudioDataInExports {
                let snapshot = studioStore.currentSnapshot()
                if let data = try? JSONEncoder().encode(snapshot),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    payload["freelance"] = json
                }
            }
            
            // Serialize
            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            
            // Write to a temporary file
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
        // 1. Reset settings store
        store.resetAllData()
        
        // 2. Clear SwiftData
        do {
            try persistence.purgeExpensesAndGoals()
            
            // 3. Reset Freelance Hub store
            studioStore.resetAllData()
            
            // 4. Refresh brain snapshots
            brain.refreshExpenses()
            
            self.showSuccessAlert = true
        } catch {
            print("Database purge failed: \(error)")
        }
    }
}
