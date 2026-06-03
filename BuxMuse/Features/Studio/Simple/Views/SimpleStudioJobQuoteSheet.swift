//
//  SimpleStudioJobQuoteSheet.swift
//  BuxMuse
//
//  Quote a job — agreed price, costs, payments, live profit math.
//

import SwiftUI

private enum SimpleJobPaymentMode: String, CaseIterable, Identifiable {
    case waiting = "Still waiting"
    case partial = "Partially paid"
    case paid = "Paid in full"

    var id: String { rawValue }
}

struct SimpleStudioJobQuoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @ObservedObject private var settings = SettingsStore.shared

    @ObservedObject var store: SimpleStudioStore

    var existingJob: SimpleStudioEntry?

    @State private var customerName = ""
    @State private var customerPhone = ""
    @State private var jobLabel = ""
    @State private var paymentMode: SimpleJobPaymentMode = .waiting
    @State private var payStyle: SimpleJobPayStyle = .onePrice
    @State private var agreedPriceText = ""
    @State private var hourlyRateText = ""
    @State private var paidSoFarText = ""
    @State private var advanceText = ""
    @State private var materialsText = ""
    @State private var petrolText = ""
    @State private var transportText = ""
    @State private var platformFeeText = ""
    @State private var note = ""
    @State private var hasPlannedTime = false
    @State private var planHours = 1
    @State private var planMinutes = 0
    @State private var pauseWhenTimeUp = true

    private var breakdown: SimpleJobBreakdown? {
        draftEntry.jobBreakdown()
    }

    private var draftEntry: SimpleStudioEntry {
        let paidAmount: Decimal = {
            switch paymentMode {
            case .waiting: return 0
            case .partial: return decimal(from: paidSoFarText) ?? 0
            case .paid: return decimal(from: agreedPriceText) ?? decimal(from: paidSoFarText) ?? 0
            }
        }()
        return SimpleStudioEntry(
            id: existingJob?.id ?? UUID(),
            kind: .job,
            amount: paidAmount,
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            customerId: linkedCustomerId,
            jobLabel: jobLabel.isEmpty ? nil : jobLabel,
            note: note.isEmpty ? nil : note,
            paymentStatus: paymentStatus,
            platformFee: decimal(from: platformFeeText),
            materials: decimal(from: materialsText),
            petrol: decimal(from: petrolText),
            transport: decimal(from: transportText),
            advanceAmount: decimal(from: advanceText),
            agreedPrice: decimal(from: agreedPriceText),
            payStyle: payStyle,
            hourlyRate: payStyle == .byTheHour ? decimal(from: hourlyRateText) : nil,
            plannedWorkSeconds: hasPlannedTime
                ? StudioWorkClockPlanEngine.duration(hours: planHours, minutes: planMinutes)
                : nil,
            pauseWhenPlanEnds: hasPlannedTime ? pauseWhenTimeUp : nil,
            createdAt: existingJob?.createdAt ?? Date()
        )
    }

    private var linkedCustomerId: UUID? {
        store.customer(named: customerName)?.id
    }

    private var paymentStatus: SimplePaymentStatus {
        switch paymentMode {
        case .waiting: return .unpaid
        case .partial: return .partial
        case .paid: return .paid
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxTokens.block) {
                        BuxThemedCardForm {
                            BuxFormSection(title: "Customer") {
                                TextField("Name", text: $customerName)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField("Phone / WhatsApp", text: $customerPhone)
                                    .keyboardType(.phonePad)
                                    .buxFormFieldPadding()
                                customerChips
                            }

                            BuxFormSection(title: "Job") {
                                TextField("What is the work?", text: $jobLabel)
                                    .buxFormFieldPadding()
                            }

                            BuxFormSection(title: "How do you get paid?") {
                                Picker("Pay type", selection: $payStyle) {
                                    ForEach(SimpleJobPayStyle.allCases) { style in
                                        Text(style.plainTitle).tag(style)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, BuxTokens.section)
                                .padding(.vertical, 10)

                                if payStyle == .onePrice {
                                    Text("One total price for the job — your work clock only tracks time, not money.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                        .padding(.horizontal, BuxTokens.section)
                                        .padding(.bottom, 6)
                                    BuxFormRowDivider()
                                    TextField("Full price you agreed", text: $agreedPriceText)
                                        .keyboardType(.decimalPad)
                                        .buxFormFieldPadding()
                                } else {
                                    Text("You charge per hour — the work clock multiplies hours × your rate.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                        .padding(.horizontal, BuxTokens.section)
                                        .padding(.bottom, 6)
                                    BuxFormRowDivider()
                                    TextField("Your rate per hour", text: $hourlyRateText)
                                        .keyboardType(.decimalPad)
                                        .buxFormFieldPadding()
                                    BuxFormRowDivider()
                                    TextField("Ballpark total (optional)", text: $agreedPriceText)
                                        .keyboardType(.decimalPad)
                                        .buxFormFieldPadding()
                                }
                            }

                            BuxFormSection(title: "How long should it take?") {
                                Toggle(isOn: $hasPlannedTime) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Set a time for this job")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Lock Screen shows a walker moving toward done — clock can stop when time is up.")
                                            .font(.system(size: 11))
                                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                    }
                                }
                                .padding(.horizontal, BuxTokens.section)
                                .padding(.vertical, 10)

                                if hasPlannedTime {
                                    BuxFormRowDivider()
                                    HStack(spacing: BuxTokens.tight) {
                                        Picker("Hours", selection: $planHours) {
                                            ForEach(0..<13, id: \.self) { Text("\($0) h").tag($0) }
                                        }
                                        .pickerStyle(.menu)
                                        Picker("Minutes", selection: $planMinutes) {
                                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                                                Text("\(m) m").tag(m)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    .padding(.horizontal, BuxTokens.section)
                                    .padding(.bottom, 8)

                                    BuxFormRowDivider()
                                    Toggle(isOn: $pauseWhenTimeUp) {
                                        Text("Stop the clock when time is up")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .padding(.horizontal, BuxTokens.section)
                                    .padding(.vertical, 10)

                                    if payStyle == .byTheHour {
                                        Text("Example: agreed 2 hours at your hourly rate — set 2 h here and the clock pauses at 2 h.")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                            .padding(.horizontal, BuxTokens.section)
                                            .padding(.bottom, 8)
                                    }
                                }
                            }

                            BuxFormSection(title: "Payment status") {
                                Picker("Status", selection: $paymentMode) {
                                    ForEach(SimpleJobPaymentMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .buxFormFieldPadding()
                                .onChange(of: paymentMode) { _, mode in
                                    if mode == .waiting {
                                        paidSoFarText = ""
                                    } else if mode == .paid, let agreed = decimal(from: agreedPriceText) {
                                        paidSoFarText = "\(agreed)"
                                    }
                                }

                                if paymentMode == .partial {
                                    BuxFormRowDivider()
                                    costRow("Paid so far", text: $paidSoFarText)
                                }
                            }

                            BuxFormSection(title: "Advance") {
                                costRow("Advance for materials", text: $advanceText)
                            }

                            BuxFormSection(title: "What you spent") {
                                costRow("Materials purchased", text: $materialsText)
                                BuxFormRowDivider()
                                costRow("Petrol / gas", text: $petrolText)
                                BuxFormRowDivider()
                                costRow("Transport", text: $transportText)
                                if settings.studioPersona == .tasksAndGigs {
                                    BuxFormRowDivider()
                                    costRow("Platform fee", text: $platformFeeText)
                                }
                            }

                            BuxFormSection(title: "Note") {
                                TextField("Optional", text: $note)
                                    .buxFormFieldPadding()
                            }
                        }

                        if let breakdown {
                            calculationCard(breakdown)
                                .padding(.horizontal, BuxTokens.marginRegular)
                        }

                        VStack(spacing: BuxTokens.tight) {
                            BuxButton(
                                title: "Send quote",
                                systemImage: "paperplane.fill",
                                role: .secondary,
                                expands: true,
                                isEnabled: canSave
                            ) {
                                sendQuote()
                            }

                            BuxButton(
                                title: existingJob == nil ? "Save job" : "Update job",
                                systemImage: "checkmark",
                                role: .primary,
                                expands: true,
                                isEnabled: canSave
                            ) {
                                save()
                            }
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                        .padding(.bottom, BuxTokens.sheetBottomClearance)
                    }
                    .padding(.top, BuxTokens.section)
                }
            }
            .navigationTitle(existingJob == nil ? "Quote job" : "Edit job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxStudioSheetContent()
            .onAppear(perform: loadExisting)
        }
    }

    @ViewBuilder
    private var customerChips: some View {
        if !store.recentCustomerNames().isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.recentCustomerNames()) { customer in
                        Button(customer.name) {
                            customerName = customer.name
                            if customerPhone.isEmpty, let phone = customer.phone {
                                customerPhone = phone
                            }
                            if jobLabel.isEmpty, let label = customer.lastJobLabel {
                                jobLabel = label
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.accentWash(for: colorScheme))
                        .foregroundColor(themeManager.current.accentColor)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, BuxTokens.section)
                .padding(.bottom, BuxTokens.section)
            }
        }
    }

    private func calculationCard(_ b: SimpleJobBreakdown) -> some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                Text("Job math")
                    .font(.system(size: 13, weight: .bold))
                    .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))

                calcRow("Agreed with customer", appSettingsManager.format(b.agreed), accent: themeManager.current.accentColor)
                calcRow("Spent on job", appSettingsManager.format(b.spent), accent: .orange)
                calcRow("Paid so far", appSettingsManager.format(b.paidSoFar), accent: .green)
                calcRow("Still waiting", appSettingsManager.format(b.balanceDue), accent: .yellow)
                Divider().opacity(0.1)
                calcRow("You keep (so far)", appSettingsManager.format(b.keptSoFar), accent: .green, bold: true)
                calcRow("You'll keep (when paid)", appSettingsManager.format(b.projectedKept), accent: themeManager.current.accentColor, bold: true)
            }
        }
    }

    private func calcRow(_ title: String, _ value: String, accent: Color, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: bold ? .bold : .medium))
                .buxLabelSecondary()
            Spacer()
            Text(value)
                .font(.system(size: bold ? 16 : 14, weight: bold ? .bold : .semibold, design: .rounded))
                .foregroundColor(accent)
        }
    }

    private func costRow(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
        }
        .buxFormFieldPadding()
    }

    private var canSave: Bool {
        let hasBasics = !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !jobLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasBasics else { return false }
        switch payStyle {
        case .onePrice:
            return decimal(from: agreedPriceText) != nil || decimal(from: paidSoFarText) != nil
        case .byTheHour:
            return (decimal(from: hourlyRateText) ?? 0) > 0
        }
    }

    private var businessName: String {
        let b = studioStore.profile.businessName
        return b.isEmpty ? SettingsStore.shared.resolvedDisplayName : b
    }

    private var shareMessage: String {
        switch payStyle {
        case .onePrice:
            let agreed = appSettingsManager.format(decimal(from: agreedPriceText) ?? decimal(from: paidSoFarText) ?? 0)
            return "Quote for \(jobLabel): \(agreed) total"
        case .byTheHour:
            let rate = appSettingsManager.format(decimal(from: hourlyRateText) ?? 0)
            return "Quote for \(jobLabel): \(rate) per hour"
        }
    }

    private func loadExisting() {
        guard let job = existingJob else { return }
        customerName = job.customerName
        if let person = store.customer(named: job.customerName) {
            customerPhone = person.phone ?? ""
        }
        jobLabel = job.jobLabel ?? ""
        payStyle = job.resolvedPayStyle
        agreedPriceText = job.agreedPrice.map { "\($0)" } ?? ""
        hourlyRateText = job.hourlyRate.map { "\($0)" } ?? ""
        if let plan = StudioWorkClockPlanEngine.normalizedPlan(job.plannedWorkSeconds) {
            hasPlannedTime = true
            let split = StudioWorkClockPlanEngine.split(plan)
            planHours = max(0, split.hours)
            planMinutes = split.minutes
        } else {
            hasPlannedTime = false
        }
        pauseWhenTimeUp = job.resolvedPauseWhenPlanEnds
        paidSoFarText = job.amount > 0 ? "\(job.amount)" : ""
        advanceText = job.advanceAmount.map { "\($0)" } ?? ""
        materialsText = job.materials.map { "\($0)" } ?? ""
        petrolText = job.petrol.map { "\($0)" } ?? ""
        transportText = job.transport.map { "\($0)" } ?? ""
        platformFeeText = job.platformFee.map { "\($0)" } ?? ""
        note = job.note ?? ""
        if job.isJobFullyPaid {
            paymentMode = .paid
        } else if job.amount > 0 {
            paymentMode = .partial
        } else {
            paymentMode = .waiting
        }
    }

    private func save() {
        let entry = draftEntry
        if payStyle == .byTheHour, let rate = decimal(from: hourlyRateText) {
            store.hourlyRateHint = rate
        }
        if existingJob != nil {
            store.updateEntry(entry)
        } else {
            store.addEntry(entry)
        }
        if !customerPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.saveCustomerPhone(name: customerName, phone: customerPhone)
        }
        BuxSaveFeedback.success()
        dismiss()
    }

    private func sendQuote() {
        let agreed = appSettingsManager.format(decimal(from: agreedPriceText) ?? 0)
        let message = "Quote for \(jobLabel): \(agreed)"
        let card = SimpleQuoteCardView(
            businessName: businessName,
            customerName: customerName,
            jobLabel: jobLabel,
            agreedFormatted: agreed,
            note: note.isEmpty ? nil : note,
            accent: themeManager.current.accentColor
        )
        .frame(width: 340)

        var items: [Any] = [message]
        if let image = SimpleStudioShareHelper.renderCard(card) {
            items.append(image)
        }

        let phone = customerPhone.isEmpty ? store.customer(named: customerName)?.phone : customerPhone
        SimpleStudioContactActions.present(
            SimpleStudioContactActions.Options(
                sheetTitle: "Send quote",
                message: message,
                recipientPhone: phone,
                shareItems: items
            ),
            openURL: openURL
        )
    }

    private func decimal(from text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }
}

struct SimpleQuoteCardView: View {
    let businessName: String
    let customerName: String
    let jobLabel: String
    let agreedFormatted: String
    let note: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(businessName)
                        .font(.system(size: 18, weight: .bold))
                    Text("Job Quote")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("QUOTE")
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.15))
                    .foregroundColor(accent)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("For")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(customerName)
                    .font(.system(size: 16, weight: .semibold))
                Text(jobLabel)
                    .font(.system(size: 14, weight: .medium))
            }

            HStack {
                Text("Agreed price")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(agreedFormatted)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
            }

            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("Sent via BuxMuse · Not a bank")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.hero, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.hero, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}
