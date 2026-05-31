//
//  SimpleStudioScanView.swift
//  BuxMuse
//
//  Picture-first scan → editable chips → save to Simple Studio ledger.
//

import SwiftUI
import PhotosUI
import VisionKit

struct SimpleStudioScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settings = SettingsStore.shared

    @ObservedObject var store: SimpleStudioStore

    var existingEntry: SimpleStudioEntry?

    @State private var isScanning = false
    @State private var showCameraSheet = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showReview = false

    @State private var scannedImage: UIImage?
    @State private var draft = SimpleScanDraft()
    @State private var editingField: SimpleScanField?

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxTokens.block) {
                        if !showReview {
                            captureCard
                        } else {
                            reviewContent
                        }
                    }
                    .padding(.top, BuxTokens.section)
                    .padding(.bottom, BuxTokens.sheetBottomClearance)
                }
            }
            .navigationTitle(existingEntry == nil ? "Scan" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                if showReview {
                    ToolbarItem(placement: .confirmationAction) {
                        BuxToolbarSaveButton(isDirty: canSave) { save() }
                    }
                }
            }
            .buxStudioSheetContent()
            .sheet(isPresented: $showCameraSheet) {
                DocumentScannerView(
                    onFinish: { img in
                        showCameraSheet = false
                        processImage(img)
                    },
                    onCancel: { showCameraSheet = false },
                    onError: { _ in
                        showCameraSheet = false
                        simulateScan()
                    }
                )
            }
            .sheet(item: $editingField) { field in
                SimpleScanChipEditorSheet(
                    field: field,
                    draft: $draft,
                    scanKinds: scanKinds
                )
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    if let img = await PhotoImageLoader.loadUIImage(from: item) {
                        processImage(img)
                    }
                }
            }
            .onAppear(perform: loadExistingIfNeeded)
        }
    }

    private func loadExistingIfNeeded() {
        guard let existingEntry, !showReview else { return }
        draft = SimpleScanDraft(entry: existingEntry)
        scannedImage = SimpleStudioScanImageStore.load(path: existingEntry.sourcePhotoPath)
        showReview = true
    }

    // MARK: - Capture

    private var captureCard: some View {
        VStack(spacing: BuxTokens.block) {
            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(themeManager.current.accentColor)

                    Text("Snap a payment or receipt")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text("Bank transfer, WhatsApp payment, platform payout, hardware receipt — all stay on your phone.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BuxTokens.section)
            }
            .padding(.horizontal, BuxTokens.marginRegular)

            if isScanning {
                ProgressView("Reading photo…")
                    .tint(themeManager.current.accentColor)
            } else {
                VStack(spacing: BuxTokens.tight) {
                    BuxButton(
                        title: VNDocumentCameraViewController.isSupported ? "Take photo" : "Simulate scan",
                        systemImage: "camera.fill",
                        role: .primary,
                        expands: true
                    ) {
                        if VNDocumentCameraViewController.isSupported {
                            showCameraSheet = true
                        } else {
                            simulateScan()
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Choose from photos")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.accentWash(for: colorScheme))
                        .foregroundColor(themeManager.current.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BuxTokens.marginRegular)
            }
        }
    }

    // MARK: - Review

    private var reviewContent: some View {
        VStack(spacing: BuxTokens.block) {
            if let scannedImage {
                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.tight) {
                    Image(uiImage: scannedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, BuxTokens.marginRegular)
            }

            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxSectionHeader(title: "Tap to fix")
                    .padding(.horizontal, BuxTokens.marginRegular)

                chipGrid
                    .padding(.horizontal, BuxTokens.marginRegular)
            }

            BuxButton(
                title: existingEntry == nil ? "Save to ledger" : "Update entry",
                systemImage: "checkmark.circle.fill",
                role: .primary,
                expands: true,
                isEnabled: canSave
            ) {
                save()
            }
            .padding(.horizontal, BuxTokens.marginRegular)

            BuxButton(
                title: "Send",
                systemImage: "paperplane.fill",
                role: .secondary,
                expands: true,
                isEnabled: canSave
            ) {
                sendDraft()
            }
            .padding(.horizontal, BuxTokens.marginRegular)
        }
    }

    private var chipGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: BuxTokens.tight), GridItem(.flexible(), spacing: BuxTokens.tight)],
            spacing: BuxTokens.tight
        ) {
            ForEach(visibleFields) { field in
                scanChip(field)
            }
        }
    }

    private var visibleFields: [SimpleScanField] {
        var fields: [SimpleScanField] = [.kind, .amount, .customer]
        if draft.kind == .job || draft.kind == .income {
            fields.append(.jobLabel)
        }
        if draft.kind == .job || draft.kind == .owedToMe {
            fields.append(.payment)
        }
        fields.append(.note)
        return fields
    }

    private func scanChip(_ field: SimpleScanField) -> some View {
        Button {
            editingField = field
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: field.systemImage)
                        .font(.system(size: 11, weight: .bold))
                    Text(field.chipTitle)
                        .font(.system(size: 10, weight: .semibold))
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                }
                Text(chipValue(for: field))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(BuxTokens.section)
            .background(themeManager.cardFill(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                    .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chipValue(for field: SimpleScanField) -> String {
        switch field {
        case .kind:
            return draft.kind.logTitle
        case .amount:
            return draft.amount > 0 ? appSettingsManager.format(draft.amount) : "Tap to add"
        case .customer:
            return draft.customerName.isEmpty ? "Tap to add" : draft.customerName
        case .jobLabel:
            return draft.jobLabel.isEmpty ? "Tap to add" : draft.jobLabel
        case .note:
            return draft.note.isEmpty ? "Optional" : draft.note
        case .payment:
            switch draft.paymentStatus {
            case .paid: return "Paid"
            case .unpaid: return "Still waiting"
            case .partial: return "Partial"
            }
        }
    }

    // MARK: - Actions

    private var scanKinds: [SimpleEntryKind] {
        settings.studioPersona == .lending
            ? SimpleEntryKind.lendingKinds + [.income, .expense, .job]
            : SimpleEntryKind.dailyLogKinds
    }

    private var canSave: Bool {
        draft.amount > 0
    }

    private func processImage(_ image: UIImage) {
        isScanning = true
        scannedImage = image
        SimpleStudioScanEngine.parseImage(image, persona: settings.studioPersona) { result in
            DispatchQueue.main.async {
                isScanning = false
                showReview = true
                switch result {
                case .success(let parsed):
                    draft = parsed
                case .failure:
                    draft = SimpleStudioScanEngine.simulatorDraft(persona: settings.studioPersona)
                }
            }
        }
    }

    private func simulateScan() {
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isScanning = false
            showReview = true
            draft = SimpleStudioScanEngine.simulatorDraft(persona: settings.studioPersona)
        }
    }

    private func save() {
        if let existingEntry {
            var entry = draft.asEntry(sourcePhotoPath: existingEntry.sourcePhotoPath)
            entry.id = existingEntry.id
            entry.createdAt = existingEntry.createdAt
            entry.customerId = existingEntry.customerId
            if let image = scannedImage, existingEntry.sourcePhotoPath == nil {
                entry.sourcePhotoPath = SimpleStudioScanImageStore.save(image, id: existingEntry.id)
            }
            store.updateEntry(entry)
        } else {
            let entryId = UUID()
            var entry = draft.asEntry(sourcePhotoPath: nil)
            entry.id = entryId
            if let image = scannedImage {
                entry.sourcePhotoPath = SimpleStudioScanImageStore.save(image, id: entryId)
            }
            store.addEntry(entry)
        }
        BuxSaveFeedback.success()
        dismiss()
    }

    private func sendDraft() {
        let message = "\(draft.kind.logTitle): \(appSettingsManager.format(draft.amount)) — \(draft.jobLabel.isEmpty ? draft.customerName : draft.jobLabel)"
        var items: [Any] = [message]
        if let scannedImage {
            items.append(scannedImage)
        }
        let phone = store.customer(named: draft.customerName)?.phone
        SimpleStudioContactActions.present(
            SimpleStudioContactActions.Options(
                message: message,
                recipientPhone: phone,
                shareItems: items
            ),
            openURL: openURL
        )
    }
}

// MARK: - Chip editor

private struct SimpleScanChipEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let field: SimpleScanField
    @Binding var draft: SimpleScanDraft
    let scanKinds: [SimpleEntryKind]

    @State private var amountText = ""
    @State private var customerText = ""
    @State private var jobText = ""
    @State private var noteText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                BuxThemedCardForm {
                    editorContent
                }
            }
            .navigationTitle(field.chipTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarSaveButton(isDirty: true) {
                        applyEdits()
                        dismiss()
                    }
                }
            }
            .buxStudioSheetContent()
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        switch field {
        case .kind:
            BuxFormSection(title: "What is this?") {
                Picker("Type", selection: $draft.kind) {
                    ForEach(scanKinds, id: \.self) { kind in
                        Label(kind.logTitle, systemImage: kind.systemImage).tag(kind)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .buxFormFieldPadding()
            }
        case .amount:
            BuxFormSection(title: "Amount") {
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .buxFormFieldPadding()
            }
        case .customer:
            BuxFormSection(title: "Who") {
                TextField("Customer or merchant", text: $customerText)
                    .buxFormFieldPadding()
            }
        case .jobLabel:
            BuxFormSection(title: "What was it for?") {
                TextField("Job or description", text: $jobText)
                    .buxFormFieldPadding()
            }
        case .note:
            BuxFormSection(title: "Note") {
                TextField("Optional details", text: $noteText, axis: .vertical)
                    .lineLimit(2...4)
                    .buxFormFieldPadding()
            }
        case .payment:
            BuxFormSection(title: "Payment status") {
                Picker("Status", selection: $draft.paymentStatus) {
                    Text("Paid").tag(SimplePaymentStatus.paid)
                    Text("Partial").tag(SimplePaymentStatus.partial)
                    Text("Still waiting").tag(SimplePaymentStatus.unpaid)
                }
                .pickerStyle(.segmented)
                .buxFormFieldPadding()
            }
        }
    }

    private func load() {
        amountText = draft.amount > 0 ? "\(draft.amount)" : ""
        customerText = draft.customerName
        jobText = draft.jobLabel
        noteText = draft.note
    }

    private func applyEdits() {
        switch field {
        case .amount:
            if let value = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) {
                draft.amount = value
            }
        case .customer:
            draft.customerName = customerText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .jobLabel:
            draft.jobLabel = jobText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .note:
            draft.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .kind, .payment:
            break
        }
    }
}
