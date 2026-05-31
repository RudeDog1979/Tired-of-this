//
//  ProBusinessCardStudioView.swift
//  BuxMuse
//
//  Business Card Studio — gallery + entry to unified card editor.
//

import SwiftUI
import UIKit

struct ProBusinessCardStudioView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @State private var selectedDesignID: UUID?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteID: UUID?
    @State private var featuredTemplate: ProBusinessCardTemplate = .classic

    private var templateCount: Int { ProBusinessCardTemplate.launchTemplates.count }

    var body: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: BuxTokens.block) {
                    heroSection
                    featuredCarousel
                    templateGallerySection
                    designsGrid
                    addDesignButton
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.vertical, BuxTokens.section)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { selectedDesignID != nil },
            set: { if !$0 { selectedDesignID = nil } }
        )) {
            if let id = selectedDesignID {
                ProBusinessCardEditorView(designID: id)
                    .environmentObject(themeManager)
                    .environmentObject(studioStore)
            }
        }
        .onAppear {
            studioStore.ensureBusinessCardLibrary(simpleCard: simpleStudioStore.businessCard)
            featuredTemplate = studioStore.businessCardLibrary.designs.first?.template ?? .logoMark
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
                        selectedDesignID = design.id
                    }
                    BuxButton(title: "Blank card", systemImage: "plus", role: .secondary, expands: true) {
                        let design = studioStore.addBusinessCardDesign(title: "New card", template: .minimalMono)
                        selectedDesignID = design.id
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
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Featured looks")
            TabView(selection: $featuredTemplate) {
                ForEach([ProBusinessCardTemplate.classic, .swissGrid, .editorial, .geometricGrid, .circleFrame, .logoMark], id: \.self) { template in
                    featuredTemplateCard(template)
                        .tag(template)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 220)
        }
    }

    private func featuredTemplateCard(_ template: ProBusinessCardTemplate) -> some View {
        let preview = cachedSampleDesign(for: template)
        return Button {
            let design = studioStore.addBusinessCardDesign(title: template.title, template: template)
            selectedDesignID = design.id
        } label: {
            BuxCard(elevation: .card, cornerRadius: 16, padding: BuxTokens.section) {
                HStack(spacing: 16) {
                    ProBusinessCardDesignThumbnail(
                        design: preview,
                        logoData: studioStore.profile.logoData,
                        scale: 0.42,
                        galleryPreview: true
                    )
                        .frame(width: preview.aspect.previewSize.width * 0.42)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        Text(template.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        Text("Tap to start →")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(themeManager.current.accentColor)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }

    // MARK: - Template gallery

    private var templateGallerySection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "All templates")
            Text("\(templateCount) geometric & editorial presets — pick one, then customize in Bux Canvas.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ForEach(ProBusinessCardCollection.allCases) { collection in
                VStack(alignment: .leading, spacing: 8) {
                    Text(collection.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(collection.templates) { template in
                                templateStartChip(template)
                            }
                        }
                    }
                }
            }
        }
    }

    private func templateStartChip(_ template: ProBusinessCardTemplate) -> some View {
        let preview = cachedSampleDesign(for: template)
        return Button {
            let design = studioStore.addBusinessCardDesign(title: template.title, template: template)
            selectedDesignID = design.id
        } label: {
            VStack(spacing: 8) {
                ProBusinessCardDesignThumbnail(
                    design: preview,
                    logoData: studioStore.profile.logoData,
                    scale: 0.28,
                    galleryPreview: true
                )
                    .frame(width: preview.aspect.previewSize.width * 0.28, height: preview.aspect.previewSize.height * 0.28)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(spacing: 2) {
                    Text(template.title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Text(template.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
            .frame(width: 118)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buxLandingLightRim(cornerRadius: 14, intensity: .card)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Your designs

    private var designsGrid: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Your designs")
            if studioStore.businessCardLibrary.designs.isEmpty {
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
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                .buxLandingLightRim(cornerRadius: BuxTokens.Radius.card, intensity: .card)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BuxTokens.section) {
                    ForEach(studioStore.businessCardLibrary.designs) { design in
                        designTile(design)
                    }
                }
            }
        }
    }

    private func designTile(_ design: ProBusinessCardDesign) -> some View {
        let scale: CGFloat = 0.44
        return VStack(spacing: 8) {
            Button { selectedDesignID = design.id } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                    ProBusinessCardDesignThumbnail(
                        design: design,
                        logoData: studioStore.profile.logoData,
                        scale: scale,
                        skipQR: true
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: design.aspect.previewSize.height * scale + 12)
            }
            .buttonStyle(.plain)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(design.title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text("\(design.template.title) · \(design.aspect.title)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Edit") { selectedDesignID = design.id }
                    Button("Share") {
                        ProBusinessCardShareActions.shareCard(design: design, logoData: studioStore.profile.logoData)
                    }
                    Button("Duplicate") { studioStore.duplicateBusinessCardDesign(id: design.id) }
                    Button("Delete", role: .destructive) {
                        pendingDeleteID = design.id
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(BuxTokens.tight)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
        .buxLandingLightRim(cornerRadius: BuxTokens.Radius.card, intensity: .card)
    }

    private var addDesignButton: some View {
        BuxButton(title: "Browse all templates", systemImage: "square.grid.2x2", role: .secondary, expands: true) {
            let design = studioStore.addBusinessCardDesign(title: featuredTemplate.title, template: featuredTemplate)
            selectedDesignID = design.id
        }
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
