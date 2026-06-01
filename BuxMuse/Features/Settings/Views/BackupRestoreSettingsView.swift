//
//  BackupRestoreSettingsView.swift
//  BuxMuse
//
//  Encrypted .buxmuse archive backup & restore with progress UI.
//

import SwiftUI
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
    @State private var issuedRecoveryKey: String?
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
                Text("Creates a password-protected `.buxmuse` file with settings, expenses, goals, workspaces, and Studio data. Share via iCloud Drive, email, or save locally.")
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
                        Text("Generate recovery key")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Shown once after backup. Save it separately — opens the file if you forget your password. BuxMuse never stores it.")
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
                    Text("BuxMuse never saves your password or recovery key on this device. You hold both — store them in a password manager, secure note, or offline copy.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buxFormFieldPadding()

                BuxFormRowDivider()
                Button(action: { showBackupSecuritySheet = true }) {
                    HStack {
                        Image(systemName: "lock.doc.fill")
                        Text("Create encrypted backup")
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
                            Text("Share backup file")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                    }
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Restore backup") {
                Text("Restoring replaces local expenses, goals, workspaces, and Studio records on this device.")
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
                        Text("Choose backup to restore")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(restoreSecretReady ? themeManager.current.accentColor : themeManager.labelSecondary(for: colorScheme))
                }
                .disabled(!restoreSecretReady || isWorking)
                .buxFormFieldPadding()
            }
        }
        .overlay {
            if isWorking, let operation {
                ArchiveProgressOverlay(
                    operation: operation,
                    step: activeStep,
                    progress: stepProgress,
                    accent: themeManager.current.accentColor,
                    pulse: progressPulse
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isWorking)
        .sheet(isPresented: $showBackupSecuritySheet) {
            backupSecuritySheet
        }
        .sheet(isPresented: $showRecoveryKeySheet) {
            recoveryKeySheet
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
            Text("Your BuxMuse data was restored from the encrypted archive.")
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
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
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
                        Text("Remember this password")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        Text("Your backup is encrypted on this device. Without the password you choose now, the file cannot be opened — not by BuxMuse, not by support, not by anyone.")
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
                        Text("I understand — create backup")
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
            .navigationTitle("Before you backup")
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
                        Text("Save your recovery key")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        Text("This key is shown once. BuxMuse does not store it. Paste it when restoring if you forget your password.")
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
                        Text("I saved my recovery key in a safe place")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(themeManager.current.accentColor)

                    Button {
                        issuedRecoveryKey = nil
                        recoveryKeyAcknowledged = false
                        showRecoveryKeySheet = false
                    } label: {
                        Text("Done")
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
            .navigationTitle("Recovery key")
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            activeStep = step
            stepProgress = value
        }
    }

    private func performBackup(password: String) {
        isWorking = true
        operation = .backup
        errorMessage = nil
        reportProgress(.collecting, 0.08)

        Task { @MainActor in
            defer {
                isWorking = false
                operation = nil
                activeStep = nil
                stepProgress = 0
            }

            do {
                try await Task.sleep(for: .milliseconds(180))
                reportProgress(.packaging, 0.28)

                let txs = financialBridge.engine.allTransactions()
                let payload = try BuxMuseArchiveService.buildPayload(
                    settings: store,
                    hustles: HustleManager.shared.hustles,
                    selectedHustleId: HustleManager.shared.selectedHustleId,
                    transactions: txs,
                    goals: goalsViewModel.goals,
                    studioSnapshot: store.studioEnabled && store.includeStudioDataInExports
                        ? studioStore.currentSnapshot()
                        : nil,
                    simpleSnapshot: store.studioEnabled && store.includeStudioDataInExports
                        ? simpleStudioStore.snapshot
                        : nil
                )

                try await Task.sleep(for: .milliseconds(120))
                reportProgress(.encrypting, 0.58)
                let result = try BuxMuseArchiveService.encrypt(
                    payload,
                    password: password,
                    includeRecoveryKey: includeRecoveryKey
                )
                let encrypted = result.archiveData

                try await Task.sleep(for: .milliseconds(120))
                reportProgress(.writing, 0.82)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withTime]
                let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BuxMuse-backup-\(stamp).buxmuse")
                try encrypted.write(to: fileURL, options: .atomic)

                reportProgress(.finalize, 1.0)
                try await Task.sleep(for: .milliseconds(350))

                archiveURL = fileURL
                store.lastExportDate = Date()
                store.save()

                backupPassword = ""
                confirmPassword = ""
                showBackupPassword = false
                showConfirmPassword = false

                if let key = result.recoveryKey {
                    issuedRecoveryKey = key
                    recoveryKeyAcknowledged = false
                    showRecoveryKeySheet = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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

                try await Task.sleep(for: .milliseconds(150))
                let data = try Data(contentsOf: url)
                reportProgress(.validate, 0.12)
                let payload = try BuxMuseArchiveService.decrypt(data, secret: restorePassword)

                try BuxMuseArchiveService.restore(
                    payload,
                    settings: store,
                    studioStore: studioStore,
                    simpleStudioStore: simpleStudioStore,
                    persistence: persistence,
                    brain: brain,
                    onStep: { step, progress in
                        reportProgress(step, progress)
                    }
                )
                reportProgress(.finalize, 1.0)
                try await Task.sleep(for: .milliseconds(400))
                restorePassword = ""
                showRestorePassword = false
                showRestoreSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Progress overlay

private struct ArchiveProgressOverlay: View {
    let operation: ArchiveOperation
    let step: BuxMuseArchiveStep?
    let progress: Double
    let accent: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

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
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progress)

                    Image(systemName: operation.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(accent)
                        .scaleEffect(pulse ? 1.06 : 0.94)
                }

                VStack(spacing: 8) {
                    Text(operation.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    if let step {
                        Text(step.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.25), value: step)
                    }
                    ProgressView(value: progress)
                        .tint(accent)
                        .frame(width: 220)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .multilineTextAlignment(.center)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(operation.title). \(step?.rawValue ?? ""). \(Int(progress * 100)) percent.")
    }
}
