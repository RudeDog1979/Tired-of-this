//
//  ProBusinessCardStudioEditor.swift
//  BuxMuse
//
//  Unified Canva-style mobile card studio — one editor for all orientations.
//

import SwiftUI
import UIKit

struct ProBusinessCardEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioStore: StudioStore

    let designID: UUID

    @State private var draft: ProBusinessCardDesign?
    @State private var designBaseline: ProBusinessCardDesign?
    @State private var templatePreviewActive = false
    @State private var activeTab: StudioTab = .design
    @State private var pickedImage: UIImage?
    @State private var backgroundPick: UIImage?
    @State private var pickTarget: PhotoPickTarget?
    @State private var showCropSheet = false
    @State private var photoStudioSession: BuxPhotoStudioSession?
    @State private var pendingPhotoStudioTarget: BuxPhotoStudioTarget?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showSafeZone = false
    @State private var showFullscreenCanvas = false
    @State private var showImmersivePreview = false

    private enum PhotoPickTarget { case portrait, background, logo }
    private enum StudioTab: String, CaseIterable, Identifiable {
        case design, photo, content, export
        var id: String { rawValue }
        var title: String {
            switch self {
            case .design: return "Design"
            case .photo: return "Photo"
            case .content: return "Text"
            case .export: return "Export"
            }
        }
        var icon: String {
            switch self {
            case .design: return "paintpalette.fill"
            case .photo: return "person.crop.circle"
            case .content: return "textformat"
            case .export: return "square.and.arrow.up"
            }
        }
    }

    private var design: ProBusinessCardDesign? {
        draft ?? studioStore.businessCardLibrary.designs.first(where: { $0.id == designID })
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > max(geo.size.height, 560)
            if let design {
                if wide {
                    HStack(spacing: 0) {
                        previewPane(design, width: geo.size.width * 0.44, height: geo.size.height)
                        inspectorPane(design)
                    }
                } else {
                    VStack(spacing: 0) {
                        previewPane(design, width: geo.size.width, height: min(geo.size.height * 0.38, 280))
                        tabBar
                        tabScroll(design)
                    }
                }
            } else {
                ContentUnavailableView("Design not found", systemImage: "person.crop.rectangle")
            }
        }
        .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
        .navigationTitle(draft?.title ?? "Card Studio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let stored = studioStore.businessCardLibrary.designs.first(where: { $0.id == designID })
            draft = stored
            designBaseline = stored
            mutateDraft { $0.ensureCanvasDocument() }
        }
        .onDisappear {
            revertTemplatePreviewIfNeeded()
            persistDraft()
        }
        .onChange(of: pickTarget) { _, target in
            guard let target else { return }
            Task {
                if BusinessCardPhotoLibraryAccess.currentStatus() == .notDetermined {
                    _ = await BusinessCardPhotoLibraryAccess.requestAccess()
                }
                await MainActor.run {
                    GlobalImagePickerCoordinator.shared.present { image in
                        guard let image else { pickTarget = nil; return }
                        if target == .background { backgroundPick = image; showCropSheet = true }
                        else {
                            pickedImage = image
                            let studioTarget = pendingPhotoStudioTarget ?? (target == .logo ? BuxPhotoStudioTarget.logo : .profilePhoto)
                            pendingPhotoStudioTarget = nil
                            openPhotoStudio(for: studioTarget, image: image)
                        }
                        pickTarget = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let image = backgroundPick {
                ImageCropView(inputImage: image, cropShape: .roundedRectangle(cornerRadius: 0), title: "Crop background", hint: "Drag to pan · slide to zoom") { cropped in
                    if let path = SimpleStudioScanImageStore.save(cropped, id: UUID()) {
                        mutateDraft { $0.style.backgroundPhotoPath = path; $0.style.backgroundStyle = .photo }
                    }
                    backgroundPick = nil; persistDraft()
                }
                .environmentObject(themeManager)
            }
        }
        .fullScreenCover(item: $photoStudioSession) { session in
            if let design {
                BuxPhotoStudioView(
                    design: design,
                    logoData: studioStore.profile.logoData,
                    session: session
                ) { result in
                    applyPhotoStudioResult(result)
                    persistDraft()
                }
                .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showShareSheet) { ProBusinessCardShareSheet(items: shareItems) }
        .fullScreenCover(isPresented: $showFullscreenCanvas) {
            CardProCanvasView(
                design: Binding(
                    get: { draft ?? ProBusinessCardDesign(title: "Card") },
                    set: { draft = $0 }
                ),
                logoData: studioStore.profile.logoData,
                onSave: { persistDraft() },
                onPickBackgroundPhoto: { pickTarget = .background }
            )
            .environmentObject(themeManager)
        }
        .fullScreenCover(isPresented: $showImmersivePreview) {
            if let design {
                BusinessCardImmersivePreviewView(
                    design: design,
                    logoData: studioStore.profile.logoData,
                    showSafeZone: showSafeZone
                )
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: Preview

    @ViewBuilder
    private func previewPane(_ design: ProBusinessCardDesign, width: CGFloat, height: CGFloat) -> some View {
        let previewHeight = max(160, height - 88)
        VStack(spacing: 10) {
            cardOrientationBar(design)
            interactivePreview(design, maxWidth: width, maxHeight: previewHeight)
                .id("\(design.id)-\(design.aspect.rawValue)-\(design.template.rawValue)-\(Int(design.updatedAt.timeIntervalSince1970))")
            HStack(spacing: 8) {
                previewActionButton(title: "Fullscreen", icon: "arrow.up.left.and.arrow.down.right") {
                    showImmersivePreview = true
                }
                previewActionButton(title: "Bux Canvas", icon: "square.3.layers.3d") {
                    mutateDraft {
                        $0.ensureCanvasDocument()
                        CardCanvasSync.syncLogoFromStudio(to: &$0, logoData: studioStore.profile.logoData)
                    }
                    persistDraft()
                    showFullscreenCanvas = true
                }
                Menu {
                    if design.options.showsPhoto && design.style.photoScale != .off {
                        Button("Your photo") { beginPhotoStudio(for: .profilePhoto, design: design) }
                    }
                    if design.options.showsLogo {
                        Button("Business logo") { beginPhotoStudio(for: .logo, design: design) }
                    }
                    if design.style.hasBackgroundPhoto {
                        Button("Background photo") { beginPhotoStudio(for: .backgroundPhoto, design: design) }
                    }
                    if availablePhotoTargets(for: design).isEmpty {
                        Button("Add your photo") { pickTarget = .portrait }
                    }
                } label: {
                    previewActionButtonLabel(title: "Edit photo", icon: "camera.filters")
                }
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            HStack {
                Toggle("Safe zone", isOn: $showSafeZone).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(design.aspect.title + " · " + design.template.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, BuxTokens.marginRegular)
        }
        .padding(.vertical, BuxTokens.section)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.35))
    }

    private func previewActionButtonLabel(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func previewActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func interactivePreview(_ design: ProBusinessCardDesign, maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        if design.canvasDocument != nil,
           let ctx = CardCanvasRenderContext.make(design: design, logoData: studioStore.profile.logoData) {
            return AnyView(
                ProBusinessCardFitPreview(
                    context: ProBusinessCardRenderFactory.makeContext(design: design, logoData: studioStore.profile.logoData),
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    showSafeZone: showSafeZone,
                    canvasContext: ctx,
                    onPhotoPlaceholderTap: {
                        mutateDraft {
                            if $0.style.photoScale == .off { $0.style.photoScale = .medium }
                            $0.options.showsPhoto = true
                        }
                        pickTarget = .portrait
                    },
                    onLogoPlaceholderTap: { pickTarget = .logo }
                )
            )
        }
        let context = ProBusinessCardRenderFactory.makeContext(design: design, logoData: studioStore.profile.logoData)
        return AnyView(
            ProBusinessCardFitPreview(
                context: context,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                showSafeZone: showSafeZone,
                onPhotoPlaceholderTap: {
                    mutateDraft {
                        if $0.style.photoScale == .off { $0.style.photoScale = .medium }
                        $0.options.showsPhoto = true
                    }
                    pickTarget = .portrait
                },
                onLogoPlaceholderTap: { pickTarget = .logo }
            )
        )
    }

    private func cardOrientationBar(_ design: ProBusinessCardDesign) -> some View {
        HStack(spacing: 8) {
            orientationChip(title: "Landscape", aspect: .standardUS, current: design.aspect)
            orientationChip(title: "Portrait", aspect: .portraitVertical, current: design.aspect)
            orientationChip(title: "Square", aspect: .squareSocial, current: design.aspect)
        }
        .padding(.horizontal, BuxTokens.marginRegular)
    }

    private func orientationChip(title: String, aspect: ProBusinessCardAspect, current: ProBusinessCardAspect) -> some View {
        Button {
            mutateDraft { $0.applyAspectChange(aspect) }
            persistDraft()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(current == aspect ? .white : themeManager.labelPrimary(for: colorScheme))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(current == aspect ? themeManager.current.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Inspector

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(StudioTab.allCases) { tab in
                Button { activeTab = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon).font(.system(size: 14, weight: .semibold))
                        Text(tab.title).font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(activeTab == tab ? themeManager.current.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func inspectorPane(_ design: ProBusinessCardDesign) -> some View {
        VStack(spacing: 0) {
            tabBar
            tabScroll(design)
        }
    }

    private func tabScroll(_ design: ProBusinessCardDesign) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BuxTokens.block) {
                BusinessCardPhotoAccessBanner().environmentObject(themeManager)
                switch activeTab {
                case .design: designTab(design)
                case .photo: photoTab(design)
                case .content: contentTab(design)
                case .export: exportTab(design)
                }
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.vertical, BuxTokens.section)
        }
    }

    // MARK: Design tab

    private func designTab(_ design: ProBusinessCardDesign) -> some View {
        Group {
            templateSection(design)
            identitySection(design)
            fontGallerySection(design)
            typographySection(design)
            lookSection(design)
            paletteSection(design)
            aspectExtras(design)
        }
    }

    private func fontGallerySection(_ design: ProBusinessCardDesign) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Fonts")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ProBusinessCardFontID.allCases) { font in
                        Button {
                            mutateDraft {
                                $0.style.typography.fontID = font.rawValue
                                CardCanvasSync.pushQuickStudioVisuals(to: &$0)
                            }
                            persistDraft()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Aa")
                                    .font(font.font(size: 22, weight: .bold))
                                Text(font.title)
                                    .font(.system(size: 9, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(design.style.typography.fontID == font.rawValue ? .white : themeManager.labelPrimary(for: colorScheme))
                            .padding(10)
                            .frame(width: 100, alignment: .leading)
                            .background(design.style.typography.fontID == font.rawValue ? themeManager.current.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func typographySection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Type scale") {
                slider("Name size", binding(\.style.typography.nameScale), range: 0.7...1.5)
                slider("Tagline size", binding(\.style.typography.taglineScale), range: 0.7...1.5)
                slider("Contact size", binding(\.style.typography.contactScale), range: 0.7...1.5)
            }
        }
    }

    private func templateSection(_ design: ProBusinessCardDesign) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Template")
            ForEach(ProBusinessCardCollection.allCases) { collection in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(collection.templates) { t in
                            Button {
                                mutateDraft { $0.template = t; $0.applyTemplateDefaults() }
                                templatePreviewActive = draft?.template != designBaseline?.template
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: t.systemImage)
                                    Text(t.title).font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(design.template == t ? .white : themeManager.labelPrimary(for: colorScheme))
                                .padding(10)
                                .frame(width: 88)
                                .background(design.template == t ? themeManager.current.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func identitySection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Brand identity") {
                Picker("Mode", selection: identityBinding) {
                    ForEach(ProBusinessCardIdentityMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .buxFormFieldPadding()
                Text(design.style.identityMode.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Logo size", selection: logoScaleBinding) {
                    Text("S").tag(ProBusinessCardLogoScale.small)
                    Text("M").tag(ProBusinessCardLogoScale.medium)
                    Text("L").tag(ProBusinessCardLogoScale.large)
                    Text("Hero").tag(ProBusinessCardLogoScale.hero)
                }
                .pickerStyle(.segmented)
                .buxFormFieldPadding()
            }
        }
    }

    private func lookSection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Look") {
                Picker("Background", selection: backgroundStyleBinding) {
                    ForEach(ProBusinessCardBackgroundStyle.allCases) { Text($0.title).tag($0) }
                }
                .buxFormFieldPadding()
                if design.style.backgroundStyle == .photo {
                    if design.style.hasBackgroundPhoto {
                        BuxFormRowDivider()
                        slider("Background opacity", binding(\.style.backgroundPhotoOpacity), range: 0.3...1)
                    } else {
                        BuxFormRowDivider()
                        Button { pickTarget = .background } label: {
                            Label("Choose background photo", systemImage: "photo.fill.on.rectangle.fill")
                                .buxFormFieldPadding()
                        }
                    }
                }
                BuxFormRowDivider()
                Picker("Font mood", selection: binding(\.style.fontPairing)) {
                    Text("Modern").tag(ProBusinessCardFontPairing.modern)
                    Text("Classic").tag(ProBusinessCardFontPairing.classic)
                    Text("Bold").tag(ProBusinessCardFontPairing.bold)
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Border", selection: binding(\.style.borderStyle)) {
                    Text("None").tag(ProBusinessCardBorderStyle.none)
                    Text("Thin").tag(ProBusinessCardBorderStyle.thin)
                    Text("Double").tag(ProBusinessCardBorderStyle.double)
                    Text("Accent").tag(ProBusinessCardBorderStyle.accent)
                }
                .buxFormFieldPadding()
            }
        }
    }

    private func paletteSection(_ design: ProBusinessCardDesign) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Colors")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BuxBrandStyleEngine.suggestedPalettes(for: design), id: \.name) { preset in
                        Button {
                            mutateDraft { $0.palette = preset.palette; CardCanvasSync.pushQuickStudioVisuals(to: &$0) }
                            persistDraft()
                        } label: {
                            Circle()
                                .fill(Color(hex: preset.palette.accentHex))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(design.palette == preset.palette ? Color.primary : .clear, lineWidth: 2.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func aspectExtras(_ design: ProBusinessCardDesign) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxSectionHeader(title: "Print size")
            Picker("Format", selection: aspectBinding) {
                ForEach(ProBusinessCardAspect.allCases) { Text("\($0.title) · \($0.detail)").tag($0) }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: Photo tab

    private func photoTab(_ design: ProBusinessCardDesign) -> some View {
        Group {
            visibilitySection(design)
            qrInfoSection(design)
            photoControlsSection(design)
            placementGridSection(design)
            backgroundPhotoSection(design)
            watermarkSection(design)
        }
    }

    private func visibilitySection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Show on card") {
                toggle("Business logo", binding(\.options.showsLogo), onChange: { _ in
                    mutateDraft { $0.style.logoCanvas = nil }
                })
                BuxFormRowDivider()
                toggle("Your photo", binding(\.options.showsPhoto), onChange: { val in
                    mutateDraft {
                        if val, $0.style.photoScale == .off { $0.style.photoScale = .medium }
                        if !val { $0.style.photoScale = .off; $0.style.photoCanvas = nil }
                    }
                })
                BuxFormRowDivider()
                toggle("QR code", binding(\.options.showsQR), onChange: { val in
                    if val { mutateDraft { $0.style.qrCanvas = nil } }
                })
                BuxFormRowDivider()
                toggle("Skills line", binding(\.options.showsSkills))
            }
        }
    }

    private func qrInfoSection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "QR code") {
                Text("Auto-generated from your name, phone, email & website as a scannable contact card (vCard).")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buxFormFieldPadding()
                if design.options.showsQR,
                   let qr = InvoiceDesignerEngine.generateQRImage(from: design.content.vCardPayload, size: 120) {
                    BuxFormRowDivider()
                    HStack {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan to save contact")
                                .font(.system(size: 12, weight: .semibold))
                            Text(design.content.name.isEmpty ? "Add a name in Text tab" : design.content.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .buxFormFieldPadding()
                }
            }
        }
    }

    private func photoControlsSection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Your photo") {
                Picker("Size", selection: photoScaleBinding) {
                    Text("Off").tag(ProBusinessCardPhotoScale.off)
                    Text("Small").tag(ProBusinessCardPhotoScale.corner)
                    Text("Medium").tag(ProBusinessCardPhotoScale.medium)
                    Text("Hero").tag(ProBusinessCardPhotoScale.hero)
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Frame", selection: binding(\.style.photoMask)) {
                    Text("Circle").tag(CardImageMask.circle)
                    Text("Rounded").tag(CardImageMask.roundedRect)
                    Text("Square").tag(CardImageMask.none)
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Button {
                    if design.content.photoPath == nil { pickTarget = .portrait }
                    else { beginPhotoStudio(for: .profilePhoto, design: design) }
                } label: {
                    Label(design.content.photoPath == nil ? "Add photo" : "Bux Photo Lab", systemImage: "camera.filters")
                        .buxFormFieldPadding()
                }
            }
            BuxFormSection(title: "Business logo") {
                Picker("Logo frame", selection: binding(\.style.logoMask)) {
                    Text("Circle").tag(CardImageMask.circle)
                    Text("Rounded").tag(CardImageMask.roundedRect)
                    Text("Square").tag(CardImageMask.none)
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Button {
                    if studioStore.profile.logoData == nil { pickTarget = .logo }
                    else { beginPhotoStudio(for: .logo, design: design) }
                } label: {
                    Label(studioStore.profile.logoData == nil ? "Add logo" : "Edit logo in Bux Photo Lab", systemImage: "briefcase.fill")
                        .buxFormFieldPadding()
                }
            }
        }
    }

    private func placementGridSection(_ design: ProBusinessCardDesign) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Photo position")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ProBusinessCardPhotoPlacement.gridPositions) { pos in
                    placementButton(pos, selected: design.style.photoPlacement == pos)
                }
            }
            BuxSectionHeader(title: "Edge strips (hero size)")
            HStack(spacing: 8) {
                ForEach(ProBusinessCardPhotoPlacement.stripPositions) { pos in
                    placementButton(pos, selected: design.style.photoPlacement == pos, compact: true)
                }
            }
        }
    }

    private func placementButton(_ pos: ProBusinessCardPhotoPlacement, selected: Bool, compact: Bool = false) -> some View {
        Button {
            mutateDraft {
                $0.style.photoPlacement = pos
                $0.style.photoCanvas = nil
                $0.options.showsPhoto = true
                if $0.style.photoScale == .off { $0.style.photoScale = pos.isStrip ? .hero : .medium }
            }
            persistDraft()
        } label: {
            Image(systemName: pos.gridIcon)
                .font(.system(size: compact ? 12 : 14, weight: .semibold))
                .foregroundColor(selected ? .white : themeManager.labelPrimary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 10 : 14)
                .background(selected ? themeManager.current.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func backgroundPhotoSection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Background photo") {
                Button { pickTarget = .background } label: {
                    Label("Set photo background", systemImage: "photo.fill").buxFormFieldPadding()
                }
                if design.style.hasBackgroundPhoto {
                    BuxFormRowDivider()
                    slider("Opacity", binding(\.style.backgroundPhotoOpacity), range: 0.3...1)
                    BuxFormRowDivider()
                    Button { beginPhotoStudio(for: .backgroundPhoto, design: design) } label: {
                        Label("Edit in Bux Photo Lab", systemImage: "camera.filters").buxFormFieldPadding()
                    }
                    BuxFormRowDivider()
                    Button(role: .destructive) { clearBackgroundPhoto() } label: {
                        Label("Clear background", systemImage: "trash").buxFormFieldPadding()
                    }
                }
            }
        }
    }

    private func watermarkSection(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Watermark") {
                toggle("Show watermark", binding(\.style.watermark.isEnabled))
                if design.style.watermark.isEnabled {
                    BuxFormRowDivider()
                    TextField("Text", text: binding(\.style.watermark.text)).buxFormFieldPadding()
                    BuxFormRowDivider()
                    slider("Opacity", binding(\.style.watermark.opacity), range: 0.04...0.4)
                    slider("Scale", binding(\.style.watermark.scale), range: 0.5...2.2)
                    slider("Rotation", binding(\.style.watermark.rotation), range: -45...45)
                }
            }
        }
    }

    // MARK: Content tab

    private func contentTab(_ design: ProBusinessCardDesign) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Card text") {
                TextField("Design name", text: binding(\.title)).buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Name / business", text: businessNameBinding).buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Tagline / title", text: binding(\.content.tagline)).buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Phone", text: binding(\.content.phone)).keyboardType(.phonePad).buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Email", text: binding(\.content.email)).keyboardType(.emailAddress).textInputAutocapitalization(.never).buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Website", text: binding(\.content.website)).textInputAutocapitalization(.never).buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Skills", text: binding(\.content.skills), axis: .vertical).lineLimit(2...4).buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Text align", selection: binding(\.options.textAlignment)) {
                    Text("Left").tag(ProBusinessCardAlignment.leading)
                    Text("Center").tag(ProBusinessCardAlignment.center)
                }
                .buxFormFieldPadding()
            }
        }
    }

    // MARK: Export tab

    private func exportTab(_ design: ProBusinessCardDesign) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            BuxThemedCardForm {
                BuxFormSection(title: "Share your card") {
                    Text("Send via Messages, WhatsApp, Mail, or any app — includes your card image and a scannable contact file.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Button {
                        ProBusinessCardShareActions.shareCard(design: design, logoData: studioStore.profile.logoData)
                    } label: {
                        Label("Share card", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .buxFormFieldPadding()
                    }
                }
            }
            BuxButton(title: "Export PDF (print ready)", systemImage: "doc.richtext", role: .secondary, expands: true) {
                ProBusinessCardShareActions.sharePDF(design: design, logoData: studioStore.profile.logoData)
            }
            BuxButton(title: "Export PNG image", systemImage: "photo", role: .secondary, expands: true) {
                ProBusinessCardShareActions.sharePNG(design: design, logoData: studioStore.profile.logoData)
            }
            BuxButton(title: "Share contact card (.vcf)", systemImage: "person.crop.circle.badge.plus", role: .secondary, expands: true) {
                ProBusinessCardShareActions.shareVCard(design: design, logoData: studioStore.profile.logoData)
            }
        }
    }

    // MARK: Bindings & actions

    private var identityBinding: Binding<ProBusinessCardIdentityMode> {
        Binding(
            get: { draft?.style.identityMode ?? .business },
            set: { mode in
                mutateDraft {
                    $0.style.applyIdentityMode(mode)
                    $0.options.showsPhoto = $0.style.photoScale != .off
                }
                persistDraft()
            }
        )
    }

    private var logoScaleBinding: Binding<ProBusinessCardLogoScale> {
        Binding(
            get: { draft?.style.logoScale ?? .hero },
            set: { scale in
                mutateDraft {
                    $0.style.logoScale = scale
                    $0.style.logoCanvas = nil
                }
                persistDraft()
            }
        )
    }

    private var aspectBinding: Binding<ProBusinessCardAspect> {
        Binding(
            get: { draft?.aspect ?? .standardUS },
            set: { aspect in
                mutateDraft { $0.applyAspectChange(aspect) }
                persistDraft()
            }
        )
    }

    private var backgroundStyleBinding: Binding<ProBusinessCardBackgroundStyle> {
        Binding(
            get: { draft?.style.backgroundStyle ?? .solid },
            set: { style in
                mutateDraft { $0.style.backgroundStyle = style }
                persistDraft()
                if style == .photo, draft?.style.hasBackgroundPhoto != true {
                    pickTarget = .background
                }
            }
        )
    }

    private var photoScaleBinding: Binding<ProBusinessCardPhotoScale> {
        Binding(
            get: { draft?.style.photoScale ?? .off },
            set: { scale in
                mutateDraft {
                    $0.style.applyPhotoScale(scale)
                    $0.options.showsPhoto = scale != .off
                    if scale == .off { $0.style.photoCanvas = nil }
                }
                persistDraft()
            }
        )
    }

    private var businessNameBinding: Binding<String> {
        Binding(
            get: { draft?.content.name ?? "" },
            set: { v in
                mutateDraft {
                    $0.content.name = v
                    if $0.style.watermark.text.isEmpty { $0.style.watermark.text = v }
                }
                persistDraft()
            }
        )
    }

    private func binding<V>(_ keyPath: WritableKeyPath<ProBusinessCardDesign, V>) -> Binding<V> {
        Binding(
            get: {
                draft?[keyPath: keyPath]
                    ?? studioStore.businessCardLibrary.designs.first(where: { $0.id == designID })?[keyPath: keyPath]
                    ?? ProBusinessCardDesign(title: "Card")[keyPath: keyPath]
            },
            set: { v in mutateDraft { $0[keyPath: keyPath] = v; $0.updatedAt = Date() }; persistDraft() }
        )
    }

    private func toggle(_ title: String, _ b: Binding<Bool>, onChange: ((Bool) -> Void)? = nil) -> some View {
        Toggle(title, isOn: b)
            .tint(themeManager.current.accentColor)
            .buxFormFieldPadding()
            .onChange(of: b.wrappedValue) { _, v in onChange?(v); persistDraft() }
    }

    private func slider(_ title: String, _ b: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .medium))
            Slider(value: b, in: range).tint(themeManager.current.accentColor)
        }
        .buxFormFieldPadding()
    }

    private func mutateDraft(_ update: (inout ProBusinessCardDesign) -> Void) {
        if draft == nil { draft = studioStore.businessCardLibrary.designs.first(where: { $0.id == designID }) }
        guard var c = draft else { return }
        update(&c)
        draft = c
    }

    private func revertTemplatePreviewIfNeeded() {
        guard templatePreviewActive, let baseline = designBaseline else { return }
        mutateDraft { draft in
            let savedContent = draft.content
            let savedTitle = draft.title
            let savedAspect = draft.aspect
            draft.template = baseline.template
            draft.palette = baseline.palette
            draft.style = baseline.style
            draft.options = baseline.options
            draft.canvasDocument = baseline.canvasDocument
            draft.content = savedContent
            draft.title = savedTitle
            draft.aspect = savedAspect
        }
    }

    private func persistDraft() {
        templatePreviewActive = false
        if var d = draft {
            CardCanvasSync.ensureDocument(on: &d)
            CardCanvasSync.pushQuickStudioVisuals(to: &d)
            d.updatedAt = Date()
            draft = d
            studioStore.updateBusinessCardDesign(d)
        }
    }

    private func clearBackgroundPhoto() { mutateDraft { $0.style.clearBackgroundPhoto() }; persistDraft() }

    private func exportPDF(_ design: ProBusinessCardDesign) {
        ProBusinessCardShareActions.sharePDF(design: design, logoData: studioStore.profile.logoData)
    }

    private func exportPNG(_ design: ProBusinessCardDesign) {
        ProBusinessCardShareActions.sharePNG(design: design, logoData: studioStore.profile.logoData)
    }

    private func shareVCard(_ design: ProBusinessCardDesign) {
        ProBusinessCardShareActions.shareVCard(design: design, logoData: studioStore.profile.logoData)
    }

    // MARK: - Bux Photo Studio

    private func availablePhotoTargets(for design: ProBusinessCardDesign) -> [BuxPhotoStudioTarget] {
        var targets: [BuxPhotoStudioTarget] = []
        if design.options.showsPhoto, design.style.photoScale != .off, design.content.photoPath != nil {
            targets.append(.profilePhoto)
        }
        if design.options.showsLogo, studioStore.profile.logoData != nil {
            targets.append(.logo)
        }
        if design.style.hasBackgroundPhoto {
            targets.append(.backgroundPhoto)
        }
        return targets
    }

    private func beginPhotoStudio(for target: BuxPhotoStudioTarget, design: ProBusinessCardDesign) {
        guard let image = loadImage(for: target, design: design) else {
            switch target {
            case .profilePhoto: pickTarget = .portrait
            case .logo: pickTarget = .logo
            case .backgroundPhoto: pickTarget = .background
            case .canvasLayer: break
            }
            pendingPhotoStudioTarget = target
            return
        }
        openPhotoStudio(for: target, image: image, design: design)
    }

    private func openPhotoStudio(for target: BuxPhotoStudioTarget, image: UIImage, design: ProBusinessCardDesign? = nil) {
        let d = design ?? self.design
        guard let d else { return }
        let targets = availablePhotoTargets(for: d)
        let allTargets = targets.isEmpty ? [target] : targets
        photoStudioSession = BuxPhotoStudioSession(
            targets: allTargets,
            selectedTarget: target,
            image: image,
            initialTransform: initialTransform(for: target, design: d),
            initialAdjustments: initialAdjustments(for: target, design: d),
            initialMask: initialMask(for: target, design: d)
        )
    }

    private func loadImage(for target: BuxPhotoStudioTarget, design: ProBusinessCardDesign) -> UIImage? {
        switch target {
        case .profilePhoto:
            return design.content.photoPath.flatMap { SimpleStudioScanImageStore.load(path: $0) }
        case .logo:
            return studioStore.profile.logoData.flatMap { UIImage(data: $0) }
        case .backgroundPhoto:
            return design.style.backgroundPhotoPath.flatMap { SimpleStudioScanImageStore.load(path: $0) }
        case .canvasLayer:
            return nil
        }
    }

    private func initialTransform(for target: BuxPhotoStudioTarget, design: ProBusinessCardDesign) -> ProBusinessCardPhotoTransform {
        switch target {
        case .profilePhoto: return design.style.photoTransform
        case .backgroundPhoto: return design.style.photoTransform
        default: return ProBusinessCardPhotoTransform()
        }
    }

    private func initialAdjustments(for target: BuxPhotoStudioTarget, design: ProBusinessCardDesign) -> ProBusinessCardPhotoAdjustments {
        switch target {
        case .profilePhoto: return design.style.photoAdjustments
        default: return ProBusinessCardPhotoAdjustments()
        }
    }

    private func initialMask(for target: BuxPhotoStudioTarget, design: ProBusinessCardDesign) -> CardImageMask {
        switch target {
        case .profilePhoto: return design.style.photoMask
        case .logo: return design.style.logoMask
        default: return .none
        }
    }

    private func applyPhotoStudioResult(_ result: BuxPhotoStudioResult) {
        switch result.target {
        case .profilePhoto:
            if let path = SimpleStudioScanImageStore.saveBusinessCardPhoto(result.image) {
                mutateDraft {
                    $0.content.photoPath = path
                    $0.options.showsPhoto = true
                    $0.style.photoTransform = result.transform
                    $0.style.photoAdjustments = result.adjustments
                    $0.style.photoMask = result.mask
                    if $0.style.photoScale == .off { $0.style.photoScale = .medium }
                    $0.style.photoCanvas = nil
                    ProBusinessCardCanvasSeeder.ensureLayers(on: &$0)
                    CardCanvasSync.pushQuickStudioVisuals(to: &$0)
                }
            }
        case .logo:
            if let data = result.image.jpegData(compressionQuality: 0.92) {
                var profile = studioStore.profile
                profile.logoData = data
                studioStore.updateProfile(profile)
                mutateDraft {
                    $0.options.showsLogo = true
                    $0.style.logoMask = result.mask
                    CardCanvasSync.pushQuickStudioVisuals(to: &$0)
                }
            }
        case .backgroundPhoto:
            if let path = SimpleStudioScanImageStore.save(result.image, id: UUID()) {
                mutateDraft {
                    $0.style.backgroundPhotoPath = path
                    $0.style.backgroundStyle = .photo
                    $0.style.photoTransform = result.transform
                    CardCanvasSync.pushQuickStudioVisuals(to: &$0)
                }
            }
        case .canvasLayer:
            break
        }
    }
}

private struct ProBusinessCardShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct BusinessCardImmersivePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let design: ProBusinessCardDesign
    let logoData: Data?
    var showSafeZone: Bool

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(design.aspect.title) · \(design.template.title)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Color.clear.frame(width: 52)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                GeometryReader { geo in
                    let context = ProBusinessCardRenderFactory.makeContext(design: design, logoData: logoData)
                    ProBusinessCardFitPreview(
                        context: context,
                        maxWidth: geo.size.width - 32,
                        maxHeight: geo.size.height - 16,
                        showSafeZone: showSafeZone
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
