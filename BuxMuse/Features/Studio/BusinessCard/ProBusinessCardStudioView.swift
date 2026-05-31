//
//  ProBusinessCardStudioView.swift
//  BuxMuse
//
//  Business Card Studio — gallery + entry to unified card editor.
//

import SwiftUI
import UIKit

struct BusinessCardEditorRoute: Identifiable, Hashable {
    let designID: UUID
    var id: UUID { designID }
}

struct ProBusinessCardStudioView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @State private var editorRoute: BusinessCardEditorRoute?
    @State private var showDesignsLibrary = false
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteID: UUID?
    @State private var featuredTemplate: ProBusinessCardTemplate = .classic

    private var templateCount: Int { ProBusinessCardTemplate.launchTemplates.count }

    private static let featuredTemplates: [ProBusinessCardTemplate] = [
        .classic, .swissGrid, .editorial, .geometricGrid, .circleFrame, .logoMark
    ]

    var body: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: BuxTokens.block) {
                    heroSection
                    featuredCarousel
                    templateShowcase
                    designsGrid
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.vertical, BuxTokens.section)
            }
            .buxRootScrollEdgeChrome()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $editorRoute) { route in
            ProBusinessCardEditorView(designID: route.designID)
                .environmentObject(themeManager)
                .environmentObject(studioStore)
        }
        .navigationDestination(isPresented: $showDesignsLibrary) {
            BusinessCardYourDesignsLibraryView(
                onSelectDesign: { openEditor(designID: $0) }
            )
            .environmentObject(themeManager)
            .environmentObject(studioStore)
        }
        .onAppear {
            studioStore.purgeEphemeralBusinessCardDesigns()
            studioStore.ensureBusinessCardLibrary(simpleCard: simpleStudioStore.businessCard)
            featuredTemplate = studioStore.businessCardLibrary.savedDesigns.first?.template ?? .logoMark
        }
        .alert("Delete this design?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID {
                    studioStore.deleteBusinessCardDesign(id: id)
                }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: 14) {
                BusinessCardStudioHeader()
                    .environmentObject(themeManager)

                Text("Design print-ready cards in minutes — geometric templates, Bux Canvas, photo lab, and export to PDF or vCard.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    heroPill("\(templateCount) templates", icon: "square.grid.3x3.fill")
                    heroPill("Bux Canvas", icon: "square.3.layers.3d")
                    heroPill("Print & QR", icon: "printer.fill")
                }

                HStack(spacing: 10) {
                    BuxButton(title: "New from template", systemImage: "sparkles", expands: true) {
                        let design = studioStore.addBusinessCardDesign(title: featuredTemplate.title, template: featuredTemplate)
                        openEditor(designID: design.id)
                    }
                    BuxButton(title: "Blank card", systemImage: "plus", role: .secondary, expands: true) {
                        let design = studioStore.addBusinessCardDesign(title: "New card", template: .minimalMono)
                        openEditor(designID: design.id)
                    }
                }
            }
        }
    }

    private func heroPill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(themeManager.current.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(themeManager.current.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Featured

    private var featuredCarousel: some View {
        BusinessCardFeaturedCarousel(
            featuredTemplate: $featuredTemplate,
            templates: Self.featuredTemplates,
            preview: cachedSampleDesign(for:),
            logoData: studioStore.profile.logoData,
            onStart: startFromTemplate
        )
        .environmentObject(themeManager)
    }

    // MARK: - All templates

    private var templateShowcase: some View {
        BusinessCardTemplateShowcase(
            preview: cachedSampleDesign(for:),
            logoData: studioStore.profile.logoData,
            onStart: startFromTemplate
        )
        .environmentObject(themeManager)
    }

    private func startFromTemplate(_ template: ProBusinessCardTemplate) {
        let design = studioStore.addBusinessCardDesign(title: template.title, template: template)
        openEditor(designID: design.id)
    }

    private func openEditor(designID: UUID) {
        // Reset so tapping the same card again still pushes.
        editorRoute = nil
        DispatchQueue.main.async {
            editorRoute = BusinessCardEditorRoute(designID: designID)
        }
    }

    private static let designsPreviewLimit = 10

    private var sortedDesigns: [ProBusinessCardDesign] {
        studioStore.businessCardLibrary.savedDesigns.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var previewDesigns: [ProBusinessCardDesign] {
        Array(sortedDesigns.prefix(Self.designsPreviewLimit))
    }

    private var hasMoreDesigns: Bool {
        sortedDesigns.count > Self.designsPreviewLimit
    }

    // MARK: - Your designs

    private var designsGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            BusinessCardStudioRibbon(
                title: "Your designs",
                subtitle: sortedDesigns.isEmpty
                    ? "Start from a template above"
                    : "\(sortedDesigns.count) saved",
                systemImage: "rectangle.stack.fill"
            )
            .environmentObject(themeManager)

            if sortedDesigns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(themeManager.current.accentColor.opacity(0.6))
                    Text("No saved cards yet")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pick a template above to create your first design.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.top, BuxTokens.section)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                .buxLandingLightRim(cornerRadius: BuxTokens.Radius.card, intensity: .card)
            } else {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: BuxTokens.section), GridItem(.flexible(), spacing: BuxTokens.section)],
                        spacing: BuxTokens.section
                    ) {
                        ForEach(previewDesigns) { design in
                            designTile(design)
                        }
                    }

                    if hasMoreDesigns {
                        Button {
                            showDesignsLibrary = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("See all \(sortedDesigns.count) designs")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(themeManager.current.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private func designTile(_ design: ProBusinessCardDesign) -> some View {
        BusinessCardDesignGridTile(
            design: design,
            logoData: studioStore.profile.logoData,
            onEdit: { openEditor(designID: design.id) },
            onShare: {
                ProBusinessCardShareActions.shareCard(design: design, logoData: studioStore.profile.logoData)
            },
            onDuplicate: { studioStore.duplicateBusinessCardDesign(id: design.id) },
            onDelete: {
                pendingDeleteID = design.id
                showDeleteConfirm = true
            }
        )
    }

    // MARK: - Sample preview

    private func cachedSampleDesign(for template: ProBusinessCardTemplate) -> ProBusinessCardDesign {
        ProBusinessCardPreviewCache.design(template: template, content: sampleContent())
    }

    private func sampleContent() -> ProBusinessCardContent {
        let businessName = studioStore.profile.businessName.isEmpty
            ? studioStore.profile.displayName
            : studioStore.profile.businessName
        let name = businessName.isEmpty ? "Your Business" : businessName
        return ProBusinessCardContent(
            name: name,
            tagline: studioStore.profile.businessType.rawValue.isEmpty ? "Professional services" : studioStore.profile.businessType.rawValue,
            phone: "+1 555 0100",
            email: "hello@business.com",
            website: "www.yoursite.com"
        )
    }
}

// MARK: - Full designs library

struct BusinessCardYourDesignsLibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioStore: StudioStore

    var onSelectDesign: (UUID) -> Void

    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteID: UUID?

    private var sortedDesigns: [ProBusinessCardDesign] {
        studioStore.businessCardLibrary.savedDesigns.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: BuxTokens.section), GridItem(.flexible(), spacing: BuxTokens.section)],
                spacing: BuxTokens.section
            ) {
                ForEach(sortedDesigns) { design in
                    BusinessCardDesignGridTile(
                        design: design,
                        logoData: studioStore.profile.logoData,
                        selectionMode: isSelecting,
                        isSelected: selectedIDs.contains(design.id),
                        onToggleSelect: { toggleSelection(design.id) },
                        onEdit: { openDesign(design.id) },
                        onShare: {
                            ProBusinessCardShareActions.shareCard(design: design, logoData: studioStore.profile.logoData)
                        },
                        onDuplicate: { studioStore.duplicateBusinessCardDesign(id: design.id) },
                        onDelete: {
                            pendingDeleteID = design.id
                            showDeleteConfirm = true
                        }
                    )
                }
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.vertical, BuxTokens.section)
        }
        .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Your designs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isSelecting {
                    Button("Cancel") {
                        isSelecting = false
                        selectedIDs = []
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(selectedIDs.isEmpty)
                } else if !sortedDesigns.isEmpty {
                    Button("Select") {
                        isSelecting = true
                    }
                }
            }
        }
        .alert("Delete this design?", isPresented: Binding(
            get: { showDeleteConfirm && !isSelecting && pendingDeleteID != nil },
            set: { if !$0 { pendingDeleteID = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID {
                    studioStore.deleteBusinessCardDesign(id: id)
                }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        }
        .alert("Delete selected designs?", isPresented: Binding(
            get: { showDeleteConfirm && isSelecting },
            set: { if !$0 { showDeleteConfirm = false } }
        )) {
            Button("Delete \(selectedIDs.count)", role: .destructive) {
                studioStore.deleteBusinessCardDesigns(ids: selectedIDs)
                selectedIDs = []
                isSelecting = false
                showDeleteConfirm = false
            }
            Button("Cancel", role: .cancel) { showDeleteConfirm = false }
        } message: {
            Text("This permanently removes the selected cards from Your designs.")
        }
    }

    private func openDesign(_ id: UUID) {
        guard !isSelecting else { return }
        onSelectDesign(id)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

// MARK: - Shared design tile

struct BusinessCardDesignGridTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let design: ProBusinessCardDesign
    let logoData: Data?
    var selectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)? = nil
    var onEdit: () -> Void
    var onShare: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        let cellInnerWidth = (UIScreen.main.bounds.width - BuxTokens.marginRegular * 2 - BuxTokens.section) / 2
        let previewSlotWidth = cellInnerWidth - BuxTokens.tight * 2 - 8
        let scale = BusinessCardGalleryScale.thumbScale(design: design, slotWidth: previewSlotWidth, maxScale: 0.42)
        let fittedW = design.aspect.previewSize.width * scale
        let fittedH = design.aspect.previewSize.height * scale
        let previewBoxHeight = previewSlotWidth * 0.64 + 12

        VStack(alignment: .leading, spacing: 6) {
            Button(action: selectionMode ? { onToggleSelect?() } : onEdit) {
                ZStack(alignment: .topTrailing) {
                    ProBusinessCardDesignThumbnail(
                        design: design,
                        logoData: logoData,
                        scale: scale,
                        skipQR: true
                    )
                    .frame(width: fittedW, height: fittedH)
                    .frame(maxWidth: .infinity)

                    if selectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(isSelected ? themeManager.current.accentColor : .white, Color.black.opacity(0.35))
                            .padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: previewBoxHeight)
                .contentShape(Rectangle())
                .overlay {
                    if selectionMode && isSelected {
                        RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                            .stroke(themeManager.current.accentColor, lineWidth: 2)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(design.title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text("\(design.template.title) · \(design.aspect.title)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !selectionMode {
                    Menu {
                        Button("Edit", action: onEdit)
                        Button("Share", action: onShare)
                        Button("Duplicate", action: onDuplicate)
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding(BuxTokens.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
    }
}
