//
//  StudioAgreementBuilderView.swift
//  BuxMuse
//
//  Guided agreement setup (additive to scratchpad editor).
//

import SwiftUI

struct StudioAgreementBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: StudioStore

    @Binding var draft: AgreementDraft
    @State private var step = 0

    private let stepTitles = ["Basics", "Scope", "Money & timing", "Review"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                BuxStepIndicator(current: step, total: stepTitles.count, labels: stepTitles)
                    .padding(.horizontal, BuxTokens.marginRegular)

                BuxThemedCardForm {
                    switch step {
                    case 0: basicsStep
                    case 1: scopeStep
                    case 2: moneyStep
                    default: reviewStep
                    }
                }
            }
            .buxCatalogNavigationTitle("Guided agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == 0 {
                        BuxToolbarCancelButton { dismiss() }
                    } else {
                        Button("Back") { step -= 1 }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if step < stepTitles.count - 1 {
                        Button("Next") { step += 1 }
                            .font(.system(size: 15, weight: .bold))
                    } else {
                        Button("Done") {
                            draft.refreshAgreementStatus()
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .bold))
                    }
                }
            }
        }
        .buxStudioSheetContent()
    }

    private var basicsStep: some View {
        BuxFormSection(title: "Who is this for?") {
            TextField("Agreement title", text: $draft.title)
                .buxFormFieldPadding()
            BuxFormRowDivider()
            Picker("Client", selection: clientBinding) {
                BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                ForEach(store.clients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }
            .pickerStyle(.menu)
            .buxFormFieldPadding()
            BuxFormRowDivider()
            Picker("Project", selection: projectBinding) {
                BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                ForEach(store.projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
            .pickerStyle(.menu)
            .buxFormFieldPadding()
        }
    }

    private var scopeStep: some View {
        BuxFormSection(title: "What are you doing?") {
            builderField("Scope (bullets or paragraphs)", text: $draft.scopeBullets)
            BuxFormRowDivider()
            builderField("Deliverables", text: $draft.deliverables)
            BuxFormRowDivider()
            builderField("Out of scope", text: $draft.outOfScope)
        }
    }

    private var moneyStep: some View {
        BuxFormSection(title: "Money & timing") {
            builderField("Price or rate (e.g. $2,400 fixed or $85/hr)", text: $draft.paymentAmountNotes)
            BuxFormRowDivider()
            builderField("Payment terms (deposit, due dates)", text: $draft.paymentTerms)
            BuxFormRowDivider()
            builderField("Timeline & milestones", text: $draft.timelineNotes)
            BuxFormRowDivider()
            TextField("Your name on signature", text: $draft.providerSignatoryName)
                .buxFormFieldPadding()
        }
    }

    private var reviewStep: some View {
        BuxFormSection(title: "Summary") {
            Text(draft.formattedShareText(
                clientName: resolvedClientName,
                projectName: resolvedProjectName,
                providerName: resolvedProviderName
            ))
            .font(.system(size: 12, weight: .regular))
            .buxLabelSecondary()
            .fixedSize(horizontal: false, vertical: true)
            .buxFormFieldPadding()
        }
    }

    private var resolvedClientName: String? {
        draft.clientId.flatMap { id in store.clients.first(where: { $0.id == id })?.name }
    }

    private var resolvedProjectName: String? {
        draft.projectId.flatMap { id in store.projects.first(where: { $0.id == id })?.name }
    }

    private var resolvedProviderName: String? {
        let custom = draft.providerSignatoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let business = store.profile.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !business.isEmpty { return business }
        return store.profile.displayName.nilIfEmpty
    }

    private var clientBinding: Binding<UUID?> {
        Binding(get: { draft.clientId }, set: { draft.clientId = $0 })
    }

    private var projectBinding: Binding<UUID?> {
        Binding(get: { draft.projectId }, set: { newId in
            draft.projectId = newId
            if let newId,
               let project = store.projects.first(where: { $0.id == newId }),
               draft.clientId == nil {
                draft.clientId = project.clientId
            }
        })
    }

    private func builderField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(3...10)
            .buxFormFieldPadding()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

/// Simple step dots for the guided builder.
private struct BuxStepIndicator: View {
    let current: Int
    let total: Int
    let labels: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index <= current ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
            Spacer()
            if current < labels.count {
                Text(labels[current])
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
            }
        }
    }
}
