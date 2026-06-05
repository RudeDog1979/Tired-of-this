//
//  StudioAgreementDealLinkButton.swift
//  BuxMuse
//

import SwiftUI

/// Opens the linked agreement from an invoice (Pro project or Simple job).
struct StudioAgreementDealLinkButton: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let agreement: AgreementDraft?
    let linkedJob: SimpleStudioEntry?
    let linkedProject: StudioProject?

    @State private var showAgreement = false

    var body: some View {
        Group {
            if agreement != nil || linkedJob != nil || linkedProject != nil {
                BuxButton(
                    title: BuxCatalogLabel.string("View deal", locale: appSettingsManager.interfaceLocale),
                    systemImage: "signature",
                    role: .secondary,
                    expands: true
                ) {
                    showAgreement = true
                }
            }
        }
        .sheet(isPresented: $showAgreement) {
            NavigationStack {
                if let job = linkedJob {
                    AgreementScratchpadEditorView(
                        job: job,
                        existingDraft: agreement ?? studioStore.agreementDraft(forJobEntryId: job.id)
                    )
                } else if let project = linkedProject {
                    AgreementScratchpadEditorView(
                        project: project,
                        existingDraft: agreement ?? studioStore.agreementDraft(forProjectId: project.id)
                    )
                } else if let agreement {
                    AgreementScratchpadEditorView(draft: agreement)
                }
            }
            .environmentObject(studioStore)
            .environmentObject(themeManager)
            .environmentObject(simpleStudioStore)
            .buxStudioSheetContent()
        }
    }
}
