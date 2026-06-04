//
//  BackupRestoreSettingsView.swift
//  BuxMuse
//
//  Encrypted .buxmuse archive backup & restore with progress UI.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ArchiveOperation {
    case backup
    case restore

    var title: String {
        switch self {
        case .backup: return "Creating backup"
        case .restore: return "Restoring backup"
        }
    }

    var systemImage: String {
        switch self {
        case .backup: return "lock.doc.fill"
        case .restore: return "arrow.counterclockwise.doc.fill"
        }
    }
}

struct BackupRestoreSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var persistence: PersistenceController
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @ObservedObject private var store = SettingsStore.shared

    @State private var backupPassword = ""
    @State private var confirmPassword = ""
    @State private var restorePassword = ""
    @State private var showBackupPassword = false
    @State private var showConfirmPassword = false
    @State private var showRestorePassword = false
    @State private var archiveURL: URL?
    @State private var showRestoreImporter = false
    @State private var showBackupSecuritySheet = false
    @State private var isWorking = false
    @State private var operation: ArchiveOperation?
    @State private var activeStep: BuxMuseArchiveStep?
    @State private var stepProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showRestoreSuccess = false
    @State private var progressPulse = false
    @State private var includeRecoveryKey = true
    @State private var showRecoveryKeySheet = false
    @State private var showBackupFileShareSheet = false
    @State private var issuedRecoveryKey: String?
    @State private var recoveryKeyPendingAfterShare: String?
    @State private var recoveryKeyAcknowledged = false

    private var passwordsMatch: Bool {
        !backupPassword.isEmpty && backupPassword == confirmPassword && backupPassword.count >= 4
    }

    private var restoreSecretReady: Bool {
        restorePassword.count >= 4 || BuxMuseRecoveryKey.isRecoveryKeyFormat(restorePassword)
    }

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Encrypted backup") {
                BuxCatalogDynamicText(key: "Creates a password-protected `.buxmuse` file with settings, expenses, goals, workspaces, and Studio data. Share via iCloud Drive, email, or save locally.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()

                BuxFormRowDivider()
                passwordField("Backup password", text: $backupPassword, isVisible: $showBackupPassword)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                passwordField("Confirm password", text: $confirmPassword, isVisible: $showConfirmPassword)
                    .buxFormFieldPadding()

                BuxFormRowDivider()
                Toggle(isOn: $includeRecoveryKey) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Generate recovery key")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Shown once after backup. Save it separately — opens the file if you forget your password. BuxMuse never stores it.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()

                BuxFormRowDivider()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.current.accentColor)
                    BuxCatalogDynamicText(key: "BuxMuse never saves your password or recovery key on this device. You hold both — store them in a password manager, secure note, or offline copy.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buxFormFieldPadding()

                BuxFormRowDivider()
                Button(action: { showBackupSecuritySheet = true }) {
                    HStack {
                        Image(systemName: "lock.doc.fill")
                        BuxCatalogDynamicText(key: "Create encrypted backup")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(passwordsMatch ? themeManager.current.accentColor : themeManager.labelSecondary(for: colorScheme))
                }
                .disabled(!passwordsMatch || isWorking)
                .buxFormFieldPadding()

                if let url = archiveURL {
                    BuxFormRowDivider()
                    ShareLink(item: url) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                            BuxCatalogDynamicText(key: "Share backup file")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                    }
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Restore backup") {
                BuxCatalogDynamicText(key: "Restoring replaces local expenses, goals, workspaces, and Studio records on this device.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()

                BuxFormRowDivider()
                passwordField("Password or recovery key", text: $restorePassword, isVisible: $showRestorePassword)
                    .buxFormFieldPadding()

                Text("Use your backup password, or paste the BM-XXXX recovery key you saved when creating the backup.")
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()

                BuxFormRowDivider()
                Button(action: { showRestoreImporter = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.doc.fill")
                        BuxCatalogDynamicText(key: "Choose backup to restore")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(restoreSecretReady ? themeManager.current.accentColor : themeManager.labelSecondary(for: colorScheme))
                }
                .disabled(!restoreSecretReady || isWorking)
                .buxFormFieldPadding()
            }
        }
        .fullScreenCover(isPresented: $isWorking) {
            if let operation {
                ArchiveProgressOverlay(
                    operation: operation,
                    step: activeStep,
                    progress: stepProgress,
                    accent: themeManager.current.accentColor,
                    pulse: progressPulse
                )
                .interactiveDismissDisabled()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isWorking)
        .sheet(isPresented: $showBackupSecuritySheet) {
            backupSecuritySheet
        }
        .sheet(isPresented: $showRecoveryKeySheet) {
            recoveryKeySheet
        }
        .sheet(isPresented: $showBackupFileShareSheet) {
            if let url = archiveURL {
                BackupArchiveShareSheet(url: url) {
                    showBackupFileShareSheet = false
                    presentRecoveryKeyIfNeeded()
                }
            }
        }
        .fileImporter(
            isPresented: $showRestoreImporter,
            allowedContentTypes: [.data, UTType(filenameExtension: "buxmuse") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importAndRestore(from: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Restore complete", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "Your BuxMuse data was restored from the encrypted archive.")
        }
        .alert("Backup error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onChange(of: isWorking) { _, working in
            if working {
                withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                    progressPulse = true
                }
            } else {
                progressPulse = false
            }
        }
    }

    // MARK: - Security confirmation sheet

    private var backupSecuritySheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    VStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [themeManager.current.accentColor, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        BuxCatalogDynamicText(key: "Remember this password")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        BuxCatalogDynamicText(key: "Your backup is encrypted on this device. Without the password you choose now, the file cannot be opened — not by BuxMuse, not by support, not by anyone.")
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        securityBullet(
                            icon: "key.fill",
                            title: "You hold the key",
                            body: "BuxMuse does not store, sync, or recover backup passwords. Everything stays local with you."
                        )
                        securityBullet(
                            icon: "folder.fill.badge.person.crop",
                            title: "Save in a safe place",
                            body: includeRecoveryKey
                                ? "Store your password and the one-time recovery key separately — password manager, secure note, or offline copy."
                                : "Use a password manager, secure note, or offline copy. Losing the password means losing access to that backup."
                        )
                        if includeRecoveryKey {
                            securityBullet(
                                icon: "key.viewfinder",
                                title: "Recovery key (optional backup)",
                                body: "After creating the backup, BuxMuse shows a recovery key once. It can unlock the file if you forget your password. We never store it."
                            )
                        }
                        securityBullet(
                            icon: "hand.raised.fill",
                            title: "Zero data leakage for us",
                            body: "We cannot decrypt your archive. Your financial data is protected by your password alone."
                        )
                    }
                    .padding(BuxTokens.section)
                    .background(themeManager.materialScheme(for: colorScheme).surfaceContainer.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button(action: confirmAndCreateBackup) {
                        BuxCatalogDynamicText(key: "I understand — create backup")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(themeManager.current.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isWorking)

                    Button("Cancel") {
                        showBackupSecuritySheet = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity)
                }
                .padding(BuxTokens.marginRegular)
            }
            .buxCatalogNavigationTitle("Before you backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarCancelButton { showBackupSecuritySheet = false }
                }
            }
            .buxThemedSheetContent()
        }
        .presentationDetents([.medium, .large])
    }

    private var recoveryKeySheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    VStack(spacing: 12) {
                        Image(systemName: "key.viewfinder")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                        BuxCatalogDynamicText(key: "Save your recovery key")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        BuxCatalogDynamicText(key: "This key is shown once. BuxMuse does not store it. Paste it when restoring if you forget your password.")
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)

                    if let key = issuedRecoveryKey {
                        Text(key)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(BuxTokens.section)
                            .background(themeManager.materialScheme(for: colorScheme).surfaceContainer.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .textSelection(.enabled)

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = key
                            } label: {
                                Label("Copy key", systemImage: "doc.on.doc.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.current.accentColor)

                            if archiveURL != nil {
                                ShareLink(item: "BuxMuse recovery key (keep private):\n\(key)\n\nBackup file saved separately.") {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Toggle(isOn: $recoveryKeyAcknowledged) {
                        BuxCatalogDynamicText(key: "I saved my recovery key in a safe place")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(themeManager.current.accentColor)

                    Button {
                        issuedRecoveryKey = nil
                        recoveryKeyAcknowledged = false
                        showRecoveryKeySheet = false
                    } label: {
                        BuxCatalogDynamicText(key: "Done")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(recoveryKeyAcknowledged ? themeManager.current.accentColor : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!recoveryKeyAcknowledged)
                }
                .padding(BuxTokens.marginRegular)
            }
            .buxCatalogNavigationTitle("Recovery key")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(!recoveryKeyAcknowledged)
            .buxThemedSheetContent()
        }
        .presentationDetents([.medium, .large])
    }

    private func securityBullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(themeManager.current.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func passwordField(_ placeholder: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: text)
                        .textContentType(.password)
                }
            }
            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
        }
    }

    // MARK: - Actions

    private func confirmAndCreateBackup() {
        guard passwordsMatch else { return }
        showBackupSecuritySheet = false
        let password = backupPassword
        performBackup(password: password)
    }

    private func reportProgress(_ step: BuxMuseArchiveStep, _ value: Double) {
        withAnimation(.easeInOut(duration: 0.95)) {
            activeStep = step
            stepProgress = value
        }
    }

    private func dwell(at step: BuxMuseArchiveStep, progress: Double, context: ArchiveProgressContext) async throws {
        reportProgress(step, progress)
        try await Task.sleep(for: ArchiveProgressPacing.dwell(for: step, context: context))
    }

    private func performBackup(password: String) {
        isWorking = true
        operation = .backup
        errorMessage = nil

        let includesStudio = store.studioEnabled && store.includeStudioDataInExports
        var context = ArchiveProgressContext(
            transactionCount: 0,
            goalCount: goalsViewModel.goals.count,
            includesStudio: includesStudio,
            archiveByteCount: 0
        )

        Task { @MainActor in
            defer {
                isWorking = false
                operation = nil
                activeStep = nil
                stepProgress = 0
            }

            do {
                try await dwell(at: .collecting, progress: 0.06, context: context)

                let txs = financialBridge.engine.allTransactions()
                context.transactionCount = txs.count

                try await dwell(at: .packaging, progress: 0.22, context: context)

                let payload = try BuxMuseArchiveService.buildPayload(
                    settings: store,
                    hustles: HustleManager.shared.hustles,
                    selectedHustleId: HustleManager.shared.selectedHustleId,
                    transactions: txs,
                    goals: goalsViewModel.goals,
                    studioSnapshot: includesStudio ? studioStore.currentSnapshot() : nil,
                    simpleSnapshot: includesStudio ? simpleStudioStore.snapshot : nil
                )

                try await dwell(at: .packaging, progress: 0.36, context: context)

                reportProgress(.encrypting, 0.42)
                let result = try BuxMuseArchiveService.encrypt(
                    payload,
                    password: password,
                    includeRecoveryKey: includeRecoveryKey
                )
                let encrypted = result.archiveData
                context.archiveByteCount = encrypted.count

                try await dwell(at: .encrypting, progress: 0.68, context: context)

                reportProgress(.writing, 0.74)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withTime]
                let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BuxMuse-backup-\(stamp).buxmuse")
                try encrypted.write(to: fileURL, options: .atomic)

                try await dwell(at: .writing, progress: 0.88, context: context)
                try await dwell(at: .finalize, progress: 1.0, context: context)

                archiveURL = fileURL
                store.lastExportDate = Date()
                store.save()

                backupPassword = ""
                confirmPassword = ""
                showBackupPassword = false
                showConfirmPassword = false

                recoveryKeyPendingAfterShare = result.recoveryKey
                showBackupFileShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func presentRecoveryKeyIfNeeded() {
        guard let key = recoveryKeyPendingAfterShare else { return }
        recoveryKeyPendingAfterShare = nil
        issuedRecoveryKey = key
        recoveryKeyAcknowledged = false
        showRecoveryKeySheet = true
    }

    private func importAndRestore(from url: URL) {
        guard restoreSecretReady else { return }
        isWorking = true
        operation = .restore
        errorMessage = nil
        reportProgress(.validate, 0.05)

        Task { @MainActor in
            defer {
                isWorking = false
                operation = nil
                activeStep = nil
                stepProgress = 0
            }

            do {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }

                var context = ArchiveProgressContext(transactionCount: 0, goalCount: 0, includesStudio: false)
                try await dwell(at: .validate, progress: 0.1, context: context)

                let data = try Data(contentsOf: url)
                try await dwell(at: .validate, progress: 0.18, context: context)

                let payload = try BuxMuseArchiveService.decrypt(data, secret: restorePassword)
                context.transactionCount = payload.manifest.transactionCount
                context.goalCount = payload.manifest.goalCount
                context.includesStudio = payload.manifest.includesStudio

                try await BuxMuseArchiveService.restore(
                    payload,
                    settings: store,
                    studioStore: studioStore,
                    simpleStudioStore: simpleStudioStore,
                    persistence: persistence,
                    brain: brain,
                    onStep: { step, progress in
                        reportProgress(step, progress)
                    },
                    paceSteps: true
                )
                try await dwell(at: .finalize, progress: 1.0, context: context)
                restorePassword = ""
                showRestorePassword = false
                showRestoreSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Progress pacing (UI dwell — real work may finish faster; we never rush the meter)

private struct ArchiveProgressContext {
    var transactionCount: Int
    var goalCount: Int
    var includesStudio: Bool
    var archiveByteCount: Int = 0
}

private enum ArchiveProgressPacing {
    /// How long each step stays on screen. Scales gently with how much data is in the archive.
    static func dwell(for step: BuxMuseArchiveStep, context: ArchiveProgressContext) -> Duration {
        let itemLoad = Double(context.transactionCount + context.goalCount)
        let sizeLoad = Double(context.archiveByteCount) / 400_000
        let volume = min(3.5, itemLoad * 0.04 + sizeLoad)
        let studio = context.includesStudio ? 0.55 : 0

        let baseSeconds: Double
        switch step {
        case .collecting: baseSeconds = 1.05
        case .packaging: baseSeconds = 1.35
        case .encrypting: baseSeconds = 1.55
        case .writing: baseSeconds = 1.0
        case .validate: baseSeconds = 0.95
        case .settings: baseSeconds = 0.85
        case .expenses: baseSeconds = 1.15
        case .goals: baseSeconds = 0.9
        case .studio: baseSeconds = 1.05
        case .finalize: baseSeconds = 1.15
        }

        let scaled = baseSeconds + volume * 0.4 + studio * 0.2
        return .milliseconds(Int(scaled * 1000))
    }
}

// MARK: - Progress screen (fullscreen canvas, single card — no dimmed “overlay” layer)

private struct ArchiveProgressOverlay: View {
    let operation: ArchiveOperation
    let step: BuxMuseArchiveStep?
    let progress: Double
    let accent: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            EncryptionMatrixBackground(accent: accent)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.18), lineWidth: 6)
                        .frame(width: 88, height: 88)
                    Circle()
                        .trim(from: 0, to: max(progress, 0.06))
                        .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.95), value: progress)

                    Image(systemName: operation.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(accent)
                        .scaleEffect(pulse ? 1.05 : 0.96)
                        .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: pulse)
                }

                VStack(spacing: 8) {
                    Text(operation.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    if let step {
                        Text(step.catalogLabel(locale: BuxInterfaceLocale.currentInterfaceLocale))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.35), value: step)
                    }
                    ProgressView(value: progress)
                        .tint(accent)
                        .frame(width: 220)
                        .animation(.easeInOut(duration: 0.95), value: progress)
                    Text(
                        BuxLocalizedString.format(
                            "%lld%%",
                            locale: BuxInterfaceLocale.currentInterfaceLocale,
                            Int64(progress * 100)
                        )
                    )
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
                .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: 340)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.22), radius: 28, y: 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(operation.title). \(step?.rawValue ?? ""). \(Int(progress * 100)) percent.")
    }
}

// MARK: - Native share sheet (Mail, Files, AirDrop, …)

private struct BackupArchiveShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async(execute: onComplete)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
