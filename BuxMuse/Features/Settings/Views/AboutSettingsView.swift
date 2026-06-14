//
//  AboutSettingsView.swift
//  BuxMuse
//
//  Credits, offline privacy agreement, and advanced developer diagnostics.
//

import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var diagnosticExportURL: URL?
    @State private var showDiagnosticConfirm = false
    @State private var isExportingDiagnostic = false
    @State private var diagnosticExportError: String?

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let format = BuxCatalogLabel.string("Version %@ (Build %@)", locale: appSettingsManager.interfaceLocale)
        return String(format: format, version, build)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(spacing: BuxTokens.block) {

                    VStack(spacing: 12) {
                        Image("BuxMuseAppIcon")
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.top, 24)

                        VStack(spacing: 4) {
                            BuxCatalogDynamicText(key: "BuxMuse")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            BuxCatalogDynamicText(key: "Your premium offline co-pilot")
                                .font(.system(size: 13, weight: .semibold))
                                .buxLabelSecondary()
                        }

                        Text(appVersionString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        BuxSectionHeader(title: "How BuxMuse works")
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 10) {
                            BuxCatalogDynamicText(key: "BuxMuse works on your device. You enter your own transactions — we never connect to your bank. Export or back up anytime.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .settingsThemedCardChrome(cornerRadius: 20)
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        BuxSectionHeader(title: "Privacy")
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                BuxCatalogDynamicText(key: "100% on-device local sandbox parsing. Your bank statements and scanned documents never touch the cloud.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }

                            Divider().padding(.vertical, 4)

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "network.slash")
                                    .foregroundColor(.red)
                                BuxCatalogDynamicText(key: "Zero network analytics trackers. Zero external APIs. BuxMuse operates fully private and autonomous.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }
                        }
                        .padding(20)
                        .settingsThemedCardChrome(cornerRadius: 20)
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        BuxSectionHeader(title: "Advanced diagnostics")
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            Toggle(isOn: $store.enableDebugOverlay) {
                                Text(BuxCatalogLabel.string("Enable debug diagnostics overlay", locale: appSettingsManager.interfaceLocale))
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)

                            Divider().opacity(0.08)

                            Toggle(isOn: $store.showPerformanceMetrics) {
                                Text(BuxCatalogLabel.string("Show FPS & cache latency", locale: appSettingsManager.interfaceLocale))
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)

                            Divider().opacity(0.08)

                            if let url = diagnosticExportURL {
                                ShareLink(item: url) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up.fill")
                                        BuxCatalogDynamicText(key: "Share diagnostic report")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, BuxLayout.section)
                                .padding(.vertical, 12)
                            } else {
                                Button {
                                    showDiagnosticConfirm = true
                                } label: {
                                    HStack {
                                        if isExportingDiagnostic {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "stethoscope")
                                        }
                                        BuxCatalogDynamicText(key: "Export diagnostic report")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .disabled(isExportingDiagnostic)
                                .padding(.horizontal, BuxLayout.section)
                                .padding(.vertical, 12)
                            }

                            BuxCatalogDynamicText(key: "Counts, versions, and storage sizes only — no names, amounts, or receipts. BuxMuse never receives this file.")
                                .font(.system(size: 11, weight: .medium))
                                .buxLabelSecondary()
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, BuxLayout.section)
                                .padding(.bottom, 12)
                        }
                        .settingsThemedCardChrome(cornerRadius: 20)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .buxScrollContentMargins()
            .buxSoftScrollChrome()
        .buxCatalogNavigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.enableDebugOverlay) { _, _ in store.save() }
        .onChange(of: store.showPerformanceMetrics) { _, _ in store.save() }
        .confirmationDialog(
            BuxCatalogLabel.string("Export diagnostic report?", locale: appSettingsManager.interfaceLocale),
            isPresented: $showDiagnosticConfirm,
            titleVisibility: .visible
        ) {
            Button(BuxCatalogLabel.string("Create report", locale: appSettingsManager.interfaceLocale)) {
                exportDiagnosticReport()
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "This report contains no personal financial data. You choose where to share it — BuxMuse never sees it.")
        }
        .alert(
            BuxCatalogLabel.string("Export failed", locale: appSettingsManager.interfaceLocale),
            isPresented: Binding(
                get: { diagnosticExportError != nil },
                set: { if !$0 { diagnosticExportError = nil } }
            )
        ) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            Text(diagnosticExportError ?? "")
        }
    }

    private func exportDiagnosticReport() {
        isExportingDiagnostic = true
        Task { @MainActor in
            defer { isExportingDiagnostic = false }
            do {
                let persistence = PersistenceController.shared
                let expenseCount = (try? persistence.fetchAllExpenseEntities().count) ?? 0
                let goalCount = (try? persistence.fetchAllGoalEntities().count) ?? 0
                let report = await BuxDiagnosticExportEngine.buildReport(
                    settings: store,
                    appSettings: appSettingsManager,
                    expenseCount: expenseCount,
                    goalCount: goalCount,
                    studioReceiptCount: StudioStore.shared.receipts.count,
                    simpleEntryCount: SimpleStudioStore.shared.entries.count
                )
                diagnosticExportURL = try BuxDiagnosticExportEngine.writeTemporaryJSON(report)
            } catch {
                diagnosticExportError = error.localizedDescription
            }
        }
    }
}
