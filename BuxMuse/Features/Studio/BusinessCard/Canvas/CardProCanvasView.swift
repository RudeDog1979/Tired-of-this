//
//  CardProCanvasView.swift
//  BuxMuse
//
//  Bux Canvas — full-screen proprietary card editor (BuxMuse).
//

import SwiftUI

struct CardProCanvasView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var design: ProBusinessCardDesign
    let logoData: Data?
    let onExit: () -> Void
    var onPickBackgroundPhoto: (() -> Void)?

    @StateObject private var undoManager = CardUndoManager()
    @State private var selectedID: UUID?
    @State private var backgroundSelected = false
    @State private var showSafeZone = true
    @State private var showSnapGuides = true
    @State private var showLayerPanel = false
    @State private var showBackgroundEditor = false
    @State private var photoStudioSession: BuxPhotoStudioSession?
    @State private var photoStudioLayerID: UUID?
    @State private var focalSession: BuxFocalSession?
    @State private var focalTarget: BuxFocalEditorTarget?
    @State private var inlineEditText = ""
    @State private var inlineEditLayerID: UUID?
    @State private var dragOrigin: CardLayerTransform?
    @State private var workspaceScale: CGFloat = 1
    @State private var workspacePan: CGSize = .zero
    @State private var lastWorkspacePan: CGSize = .zero
    @State private var lastWorkspaceScale: CGFloat = 1
    @State private var showShapePicker = false
    @State private var pinchOriginScale: Double?
    @State private var rotateOriginDegrees: Double?
    @State private var backgroundPhotoFlow: BuxBackgroundPhotoFlow?
    @State private var didCaptureInitialCanvasUndo = false
    @ObservedObject private var settings = SettingsStore.shared

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var document: CardCanvasDocument {
        design.canvasDocument ?? CardCanvasMigrator.migrate(from: design)
    }

    private var toolbarActions: BuxCanvasToolbarActionSet {
        BuxCanvasToolbarActionSet(
            onOpenPhotoLab: { id in
                guard let img = loadImage(forLayerID: id) else { return }
                let layer = design.canvasDocument?.layer(id: id)
                let payload: CardImagePayload? = {
                    guard case .image(let p) = layer?.payload else { return nil }
                    return p
                }()
                photoStudioLayerID = id
                let target: BuxPhotoStudioTarget = .canvasLayer(id)
                photoStudioSession = BuxPhotoStudioSession(
                    targets: [target],
                    selectedTarget: target,
                    image: img,
                    layerID: id,
                    initialTransform: payload?.photoTransform ?? ProBusinessCardPhotoTransform(),
                    initialAdjustments: payload?.adjustments ?? ProBusinessCardPhotoAdjustments(),
                    initialMask: payload?.mask ?? .circle
                )
            },
            onOpenFocalEditor: { target in
                guard let img = loadImage(forFocalTarget: target) else { return }
                focalTarget = target
                focalSession = BuxFocalSession(
                    target: target,
                    image: img,
                    title: focalTitle(for: target),
                    cropIsCircle: focalIsCircle(for: target)
                )
            },
            onOpenBackgroundEditor: { showBackgroundEditor = true },
            onPickBackgroundPhoto: { startBackgroundPhotoPick() },
            onAdjustBackgroundPhoto: { openBackgroundPhotoAdjust() },
            onLayerDuplicated: { selectedID = $0 },
            onLayerDeleted: { selectedID = nil }
        )
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height

            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                if landscape {
                    landscapeLayout(in: geo)
                } else {
                    portraitLayout(in: geo)
                }

                if let editID = inlineEditLayerID {
                    inlineTextOverlay(layerID: editID)
                }
            }
        }
        .buxRootBrandTheme()
        .onAppear {
            design.ensureCanvasDocument()
            CardCanvasSync.syncLogoFromStudio(to: &design, logoData: logoData)
            if !didCaptureInitialCanvasUndo, let doc = design.canvasDocument {
                undoManager.snapshot(doc)
                didCaptureInitialCanvasUndo = true
            }
            showSafeZone = design.editorPreferences?.showSafeZone ?? true
            showSnapGuides = design.editorPreferences?.showSnapGuides ?? true
        }
        .onChange(of: selectedID) { _, _ in
            resetGestureOrigins()
        }
        .sheet(isPresented: $showLayerPanel) {
            NavigationStack {
                CardLayerPanel(
                    document: canvasBinding,
                    selectedID: $selectedID,
                    backgroundSelected: $backgroundSelected,
                    onChange: { canvasToolbarDidChange() }
                )
                    .buxCatalogNavigationTitle("Bux Layers")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(BuxCatalogLabel.string("Done", locale: appSettingsManager.interfaceLocale)) { showLayerPanel = false } } }
            }
        }
        .sheet(isPresented: $showBackgroundEditor) {
            NavigationStack {
                CardBackgroundEditor(
                    background: backgroundBinding,
                    brandPalette: design.palette,
                    cardAspect: design.aspect,
                    onPickPhoto: { startBackgroundPhotoPick() },
                    onPhotoPicked: { image in
                        presentBackgroundPhotoEditor(image: image, closingBackgroundSheet: true)
                    },
                    onAdjustPhoto: {
                        showBackgroundEditor = false
                        openBackgroundPhotoAdjust()
                    },
                    onChange: { snapshotForUndo() }
                )
                .buxCatalogNavigationTitle("Bux Background")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(BuxCatalogLabel.string("Done", locale: appSettingsManager.interfaceLocale)) { showBackgroundEditor = false } } }
            }
        }
        .fullScreenCover(item: $photoStudioSession) { session in
            BuxPhotoStudioView(
                design: design,
                logoData: logoData,
                session: session
            ) { result in
                applyPhotoStudioResult(result, layerID: photoStudioLayerID ?? session.layerID)
            }
            .environmentObject(themeManager)
        }
        .fullScreenCover(item: $focalSession) { session in
            BuxPhotoFocalEditorView(
                title: session.title,
                image: session.image,
                transform: focalTransformBinding,
                cropIsCircle: session.cropIsCircle,
                viewportSize: session.viewportSize,
                viewportCornerRadius: session.viewportCornerRadius
            ) {
                snapshotForUndo()
            }
            .environmentObject(themeManager)
            .onAppear { focalTarget = session.target }
        }
        .fullScreenCover(item: $backgroundPhotoFlow) { flow in
            BuxCardBackgroundPhotoEditorView(
                initialAspect: design.aspect,
                image: flow.image,
                initialBackground: design.canvasDocument?.background ?? CardBackgroundSpec(
                    solidHex: design.palette.backgroundHex,
                    accentHex: design.palette.accentHex
                ),
                paperColorHex: design.canvasDocument?.background.solidHex ?? design.palette.backgroundHex,
                onCommitAspect: { newAspect in
                    applyCardAspectFromPhotoEditor(newAspect)
                },
                onApply: { spec in
                    applyBackgroundFromPhotoEditor(spec)
                    snapshotForUndo()
                    backgroundPhotoFlow = nil
                }
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showShapePicker) {
            BuxShapePickerSheet(
                palette: design.palette,
                onPickShape: { addShapeLayer($0) },
                onApplyPack: { applyLayoutPack($0) }
            )
        }
    }

    // MARK: - Layout

    private func portraitLayout(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar
            contextToolbar
                .padding(.top, 8)
            canvasWorkspace
                .frame(height: max(220, geo.size.height * 0.44))
            toolsPanel
        }
    }

    private func landscapeLayout(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .top, spacing: 0) {
                canvasWorkspace
                    .frame(width: geo.size.width * 0.52)
                    .frame(maxHeight: .infinity)
                    .background(themeManager.screenBackground(for: colorScheme).opacity(0.5))
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxTokens.section) {
                        contextToolbar
                        toolsPanelContent
                    }
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.vertical, BuxTokens.section)
                }
                .frame(width: geo.size.width * 0.48)
                .frame(maxHeight: .infinity)
                .background(themeManager.screenBackground(for: colorScheme))
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var contextToolbar: some View {
        CardFloatingToolbar(
            layer: selectedLayer,
            backgroundSelected: backgroundSelected,
            document: canvasBinding,
            brandPalette: design.palette,
            actions: toolbarActions,
            onChange: { canvasToolbarDidChange() }
        )
        .environmentObject(themeManager)
    }

    private var toolsPanel: some View {
        ScrollView(showsIndicators: false) {
            toolsPanelContent
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.vertical, BuxTokens.section)
        }
        .background(themeManager.screenBackground(for: colorScheme))
    }

    private var toolsPanelContent: some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            if let doc = design.canvasDocument {
                BuxCanvasElementsStrip(
                    layers: doc.layers,
                    selectedID: $selectedID,
                    backgroundSelected: $backgroundSelected,
                    onSelect: { _ in resetGestureOrigins() }
                )
                .environmentObject(themeManager)
            }

            HStack(spacing: 8) {
                railButton("Layers", icon: "square.3.layers.3d") { showLayerPanel = true }
                railButton(
                    "Background",
                    icon: "photo.fill.on.rectangle.fill",
                    isSelected: backgroundSelected
                ) {
                    backgroundSelected = true
                    selectedID = nil
                    resetGestureOrigins()
                }
                railButton("Add text", icon: "text.badge.plus") { addTextLayer() }
                railButton("Shapes", icon: "triangle.fill") { showShapePicker = true }
            }
            .buxNativeGlassButtonRowContainer(spacing: 8)

            if backgroundSelected {
                backgroundPhotoTools
                backgroundColorPanels
            }

            if let layer = selectedLayer {
                layerColorPanels(layer)
            }

            HStack(spacing: 16) {
                canvasToggleRow(title: "Safe zone", isOn: $showSafeZone)
                canvasToggleRow(title: "Snap", isOn: $showSnapGuides)
                Button(BusinessCardL10n.line("Reset zoom", locale: appSettingsManager.interfaceLocale)) { resetWorkspaceZoom() }
                    .font(.system(size: 12, weight: .semibold))
                    .buxNativeButtonStyle(.secondary)
                    .buxActionButtonChrome(role: .secondary, accent: controlTint)
                Spacer(minLength: 0)
            }
            .tint(controlTint)
            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            BuxCatalogDynamicText(key: "Pinch to resize · Two fingers to rotate · Drag handles for precision")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var topBar: some View {
        BuxCenteredTopBar(title: "Bux Canvas") {
            HStack(spacing: 8) {
                Button(BusinessCardL10n.line("Exit", locale: appSettingsManager.interfaceLocale)) { exitAndDismiss() }
                    .font(.system(size: 13, weight: .semibold))
                    .buxNativeButtonStyle(.secondary)
            }
            .buxNativeGlassButtonRowContainer()
            .foregroundStyle(controlTint)
        } trailing: {
            HStack(spacing: 8) {
                Button { undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buxNativeButtonStyle(.secondary)
                .disabled(!undoManager.canUndo)
                Button { redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buxNativeButtonStyle(.secondary)
                .disabled(!undoManager.canRedo)
            }
            .buxNativeGlassButtonRowContainer()
            .foregroundStyle(controlTint)
        }
        .background(themeManager.screenBackground(for: colorScheme))
    }

    private var canvasWorkspace: some View {
        GeometryReader { geo in
            let cardSize = design.aspect.previewSize
            let inset: CGFloat = 28
            let baseFit = min(
                (geo.size.width - inset * 2) / cardSize.width,
                (geo.size.height - inset * 2) / cardSize.height,
                1.4
            )
            let scale = baseFit * workspaceScale
            let displayW = cardSize.width * scale
            let displayH = cardSize.height * scale
            let canPanWorkspace = selectedID == nil && !backgroundSelected

            ZStack {
                themeManager.screenBackground(for: colorScheme)

                BusinessCardPreviewVisor(style: .canvas) {
                GeometryReader { visorGeo in
                    let center = CGPoint(
                        x: visorGeo.size.width / 2 + workspacePan.width,
                        y: visorGeo.size.height / 2 + workspacePan.height
                    )

                    ZStack {
                        if canPanWorkspace {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(workspacePanGesture)
                                .simultaneousGesture(workspacePinchGesture)
                        }

                        if showSnapGuides {
                            snapGuides(width: displayW, height: displayH)
                                .position(x: center.x, y: center.y)
                                .allowsHitTesting(false)
                        }

                        canvasCardStage(cardSize: cardSize)
                            .scaleEffect(scale)
                            .frame(width: displayW, height: displayH)
                            .position(x: center.x, y: center.y)
                    }
                    .frame(width: visorGeo.size.width, height: visorGeo.size.height)
                }
            }
            .environmentObject(themeManager)
            }
            .padding(BuxTokens.tight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func canvasCardStage(cardSize: CGSize) -> some View {
        ZStack {
            if backgroundSelected {
                RoundedRectangle(cornerRadius: canvasCardCornerRadius, style: .continuous)
                    .stroke(themeManager.current.accentColor, lineWidth: 2.5)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .allowsHitTesting(false)
            }

            if let ctx = CardCanvasRenderContext.make(design: design, logoData: logoData) {
                CardCanvasRenderer(
                    context: ctx,
                    selectedLayerID: nil,
                    showSafeZone: showSafeZone,
                    interactive: false
                )
                .allowsHitTesting(false)
            }

            canvasInteractionOverlay(cardSize: cardSize)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: canvasCardCornerRadius, style: .continuous))
        .coordinateSpace(name: BuxCanvasLayerTransformMath.canvasCoordinateSpaceName)
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }

    private func canvasInteractionOverlay(cardSize: CGSize) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleCanvasTap(at: location, cardSize: cardSize)
                }

            if let layer = selectedLayer, !layer.isLocked {
                let frame = layer.transform.frame(in: cardSize)
                let layerID = layer.id

                BuxCanvasSelectionChrome(
                    frame: frame,
                    accent: themeManager.contrastAccentColor(for: colorScheme),
                    rotation: layer.transform.rotation,
                    onMove: { applyMove(layerID: layerID, translation: $0, cardSize: cardSize) },
                    onMoveEnd: { finishMoveGesture() },
                    onResize: { newSize in applyResize(layerID: layerID, newSize: newSize, cardSize: cardSize) },
                    onResizeEnd: { canvasToolbarDidChange() },
                    onRotate: { applyRotation(layerID: layerID, degrees: $0) },
                    onRotateEnd: { canvasToolbarDidChange() },
                    onPinch: { applyPinch(layerID: layerID, magnification: $0) },
                    onPinchEnd: { finishPinchGesture() },
                    onPinchRotate: { applyPinchRotation(layerID: layerID, angle: $0) },
                    onPinchRotateEnd: { finishPinchRotateGesture() }
                )
            }
        }
    }

    private func applyPinch(layerID: UUID, magnification: CGFloat) {
        guard var layer = design.canvasDocument?.layer(id: layerID), !layer.isLocked else { return }
        if pinchOriginScale == nil { pinchOriginScale = layer.transform.scale }
        guard let originScale = pinchOriginScale else { return }
        layer.transform.scale = BuxCanvasLayerTransformMath.clampScale(originScale * Double(magnification))
        mutateCanvasDuringGesture { $0.updateLayer(layer) }
    }

    private func finishPinchGesture() {
        pinchOriginScale = nil
        mutateCanvas { $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private func applyPinchRotation(layerID: UUID, angle: Angle) {
        guard var layer = design.canvasDocument?.layer(id: layerID), !layer.isLocked else { return }
        if rotateOriginDegrees == nil { rotateOriginDegrees = layer.transform.rotation }
        guard let originDegrees = rotateOriginDegrees else { return }
        layer.transform.rotation = BuxCanvasLayerTransformMath.snapRotation(
            originDegrees + angle.degrees
        )
        mutateCanvasDuringGesture { $0.updateLayer(layer) }
    }

    private func finishPinchRotateGesture() {
        rotateOriginDegrees = nil
        mutateCanvas { $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private var backgroundPhotoTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Background photo")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text(
                BuxLocalizedString.format(
                    "Card: %@ — any photo size works.",
                    locale: BuxInterfaceLocale.currentInterfaceLocale,
                    design.aspect.detail
                )
            )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(BuxCatalogLabel.string("Choose photo", locale: appSettingsManager.interfaceLocale)) { startBackgroundPhotoPick() }
                    .font(.system(size: 13, weight: .semibold))
                    .buxNativeButtonStyle(.secondary)
                    .foregroundStyle(controlTint)
                if design.canvasDocument?.background.photoPath != nil {
                    Button(BuxCatalogLabel.string("Adjust", locale: appSettingsManager.interfaceLocale)) { openBackgroundPhotoAdjust() }
                        .font(.system(size: 13, weight: .semibold))
                        .buxNativeButtonStyle(.secondary)
                        .foregroundStyle(controlTint)
                }
            }
            .buxNativeGlassButtonRowContainer()
            .foregroundStyle(controlTint)
        }
    }

    private var canvasCardCornerRadius: CGFloat {
        design.aspect == .squareSocial ? 20 : 14
    }

    private func startBackgroundPhotoPick() {
        Task {
            if BusinessCardPhotoLibraryAccess.currentStatus() == .notDetermined {
                _ = await BusinessCardPhotoLibraryAccess.requestAccess()
            }
            await MainActor.run {
                let handlePicked: (UIImage?) -> Void = { image in
                    guard let image else { return }
                    presentBackgroundPhotoEditor(image: image)
                }
                if BuxPadIdiom.isPad {
                    BuxCanvasBackgroundPhotoPicker.present(onPicked: handlePicked)
                } else {
                    GlobalImagePickerCoordinator.shared.present(onPicked: handlePicked)
                }
            }
        }
    }

    private func openBackgroundPhotoAdjust() {
        if let img = SimpleStudioScanImageStore.load(path: design.canvasDocument?.background.photoPath) {
            presentBackgroundPhotoEditor(image: img)
            return
        }
        startBackgroundPhotoPick()
    }

    /// Presents the photo editor full-screen after closing any sheet that would block a second modal.
    private func presentBackgroundPhotoEditor(image: UIImage, closingBackgroundSheet: Bool = false) {
        showLayerPanel = false
        showShapePicker = false
        if closingBackgroundSheet {
            showBackgroundEditor = false
        }
        photoStudioSession = nil
        focalSession = nil
        if closingBackgroundSheet {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                backgroundPhotoFlow = BuxBackgroundPhotoFlow(image: image)
            }
        } else {
            backgroundPhotoFlow = BuxBackgroundPhotoFlow(image: image)
        }
    }

    @ViewBuilder
    private var backgroundColorPanels: some View {
        BuxDesignerColorPanel(
            title: "Card paper",
            currentHex: design.canvasDocument?.background.solidHex ?? design.palette.backgroundHex,
            brandPalette: design.palette,
            layerOpacity: nil
        ) { hex in
            mutateCanvas { doc in
                doc.background.solidHex = hex
                doc.markCustomized()
            }
            design.palette.backgroundHex = hex
            canvasToolbarDidChange()
        }
        .environmentObject(themeManager)

        BuxDesignerColorPanel(
            title: "Card accent",
            currentHex: design.canvasDocument?.background.accentHex ?? design.palette.accentHex,
            brandPalette: design.palette,
            layerOpacity: nil
        ) { hex in
            mutateCanvas { doc in
                doc.background.accentHex = hex
                doc.markCustomized()
            }
            design.palette.accentHex = hex
            canvasToolbarDidChange()
        }
        .environmentObject(themeManager)
    }

    @ViewBuilder
    private func layerColorPanels(_ layer: CardCanvasLayer) -> some View {
        switch layer.payload {
        case .text(let payload):
            BuxDesignerColorPanel(
                title: "Text color",
                currentHex: payload.style.colorHex,
                brandPalette: design.palette,
                layerOpacity: shapeLayerOpacityBinding(layerID: layer.id)
            ) { hex in
                updateTextColor(layerID: layer.id, colorHex: hex)
            }
            .environmentObject(themeManager)

        case .shape(let payload):
            BuxDesignerColorPanel(
                title: "Shape fill",
                currentHex: payload.fillHex,
                brandPalette: design.palette,
                layerOpacity: shapeLayerOpacityBinding(layerID: layer.id)
            ) { hex in
                updateShapeFill(layerID: layer.id, fillHex: hex)
            }
            .environmentObject(themeManager)

            BuxDesignerColorPanel(
                title: "Shape stroke",
                currentHex: payload.strokeHex ?? design.palette.foregroundHex,
                brandPalette: design.palette,
                layerOpacity: nil
            ) { hex in
                updateShapeStroke(layerID: layer.id, strokeHex: hex)
            }
            .environmentObject(themeManager)

        case .qr(let payload):
            BuxDesignerColorPanel(
                title: "QR ink",
                currentHex: payload.foregroundHex,
                brandPalette: design.palette,
                layerOpacity: shapeLayerOpacityBinding(layerID: layer.id)
            ) { hex in
                updateQRColors(layerID: layer.id, foregroundHex: hex, backgroundHex: nil)
            }
            .environmentObject(themeManager)

            BuxDesignerColorPanel(
                title: "QR paper",
                currentHex: payload.backgroundHex,
                brandPalette: design.palette,
                layerOpacity: nil
            ) { hex in
                updateQRColors(layerID: layer.id, foregroundHex: nil, backgroundHex: hex)
            }
            .environmentObject(themeManager)

        case .watermark(let payload):
            BuxDesignerColorPanel(
                title: "Watermark",
                currentHex: payload.colorHex,
                brandPalette: design.palette,
                layerOpacity: shapeLayerOpacityBinding(layerID: layer.id)
            ) { hex in
                updateWatermarkColor(layerID: layer.id, colorHex: hex)
            }
            .environmentObject(themeManager)

        case .image:
            EmptyView()
        }
    }

    private func updateTextColor(layerID: UUID, colorHex: String) {
        guard var layer = design.canvasDocument?.layer(id: layerID),
              case .text(var payload) = layer.payload else { return }
        payload.style.colorHex = colorHex
        layer.payload = .text(payload)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private func updateQRColors(layerID: UUID, foregroundHex: String?, backgroundHex: String?) {
        guard var layer = design.canvasDocument?.layer(id: layerID),
              case .qr(var payload) = layer.payload else { return }
        if let foregroundHex { payload.foregroundHex = foregroundHex }
        if let backgroundHex { payload.backgroundHex = backgroundHex }
        layer.payload = .qr(payload)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private func updateWatermarkColor(layerID: UUID, colorHex: String) {
        guard var layer = design.canvasDocument?.layer(id: layerID),
              case .watermark(var payload) = layer.payload else { return }
        payload.colorHex = colorHex
        layer.payload = .watermark(payload)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private func updateShapeFill(layerID: UUID, fillHex: String) {
        guard var layer = design.canvasDocument?.layer(id: layerID),
              case .shape(var payload) = layer.payload else { return }
        payload.fillHex = fillHex
        layer.payload = .shape(payload)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private func updateShapeStroke(layerID: UUID, strokeHex: String) {
        guard var layer = design.canvasDocument?.layer(id: layerID),
              case .shape(var payload) = layer.payload else { return }
        payload.strokeHex = strokeHex
        if payload.strokeWidth < 0.5 { payload.strokeWidth = 1.5 }
        layer.payload = .shape(payload)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private func shapeLayerOpacityBinding(layerID: UUID) -> Binding<Double> {
        Binding(
            get: { design.canvasDocument?.layer(id: layerID)?.opacity ?? 1 },
            set: { value in
                guard var layer = design.canvasDocument?.layer(id: layerID) else { return }
                layer.opacity = min(1, max(0.05, value))
                mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
                canvasToolbarDidChange()
            }
        )
    }

    private func applyMove(layerID: UUID, translation: CGSize, cardSize: CGSize) {
        guard var layer = design.canvasDocument?.layer(id: layerID), !layer.isLocked else { return }
        if dragOrigin == nil { dragOrigin = layer.transform }
        guard let origin = dragOrigin else { return }
        layer.transform.centerX = clamp(origin.centerX + Double(translation.width / cardSize.width))
        layer.transform.centerY = clamp(origin.centerY + Double(translation.height / cardSize.height))
        mutateCanvasDuringGesture { $0.updateLayer(layer) }
    }

    private func finishMoveGesture() {
        dragOrigin = nil
        mutateCanvas { $0.markCustomized() }
        canvasToolbarDidChange()
    }

    private var workspacePinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { m in
                workspaceScale = min(3, max(0.45, lastWorkspaceScale * m))
            }
            .onEnded { _ in lastWorkspaceScale = workspaceScale }
    }

    private var workspacePanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                workspacePan = CGSize(
                    width: lastWorkspacePan.width + v.translation.width,
                    height: lastWorkspacePan.height + v.translation.height
                )
            }
            .onEnded { _ in lastWorkspacePan = workspacePan }
    }

    @ViewBuilder
    private func selectionOverlay(cardSize: CGSize) -> some View { EmptyView() }

    private func applyLayoutPack(_ pack: BuxBrandStyleEngine.LayoutPack) {
        mutateCanvas { doc in
            BuxBrandStyleEngine.applyLayoutPack(pack, to: &doc, palette: design.palette)
        }
        snapshotForUndo()
    }

    private func addShapeLayer(_ type: CardShapeType) {
        mutateCanvas { doc in
            let layer = CardCanvasLayer(
                name: type.title,
                kind: .shape,
                transform: CardLayerTransform(centerX: 0.5, centerY: 0.5, width: 0.22, height: 0.16),
                payload: .shape(CardShapePayload(shapeType: type, fillHex: design.palette.accentHex, useGradient: type == .diamond || type == .triangle))
            )
            doc.layers.append(layer)
            doc.markCustomized()
            selectedID = layer.id
            backgroundSelected = false
        }
        snapshotForUndo()
    }

    private func resetWorkspaceZoom() {
        workspaceScale = 1
        lastWorkspaceScale = 1
        workspacePan = .zero
        lastWorkspacePan = .zero
    }

    private func railButton(
        _ title: String,
        icon: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                BuxCatalogText.text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } icon: {
                Image(systemName: icon)
            }
            .font(.system(size: 11, weight: .bold))
            .labelStyle(.titleAndIcon)
        }
        .buxNativeButtonStyle(isSelected ? .primary : .secondary)
        .buxActionButtonChrome(
            role: isSelected ? .primary : .secondary,
            accent: controlTint
        )
    }

    private func inlineTextOverlay(layerID: UUID) -> some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                .ignoresSafeArea()
                .onTapGesture { inlineEditLayerID = nil }
            VStack(spacing: 12) {
                TextField(BusinessCardL10n.line("Edit text", locale: appSettingsManager.interfaceLocale), text: $inlineEditText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) { inlineEditLayerID = nil }
                    Spacer()
                    Button(BuxCatalogLabel.string("Apply", locale: appSettingsManager.interfaceLocale)) { applyInlineEdit(layerID: layerID) }
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                }
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            }
            .padding(24)
        }
    }

    // MARK: - Gestures & transforms

    private func mutateCanvas(_ update: (inout CardCanvasDocument) -> Void) {
        guard var doc = design.canvasDocument else { return }
        update(&doc)
        design.canvasDocument = doc
        design.updatedAt = Date()
    }

    /// Avoids implicit layout animations while a finger gesture is updating the canvas.
    private func mutateCanvasDuringGesture(_ update: (inout CardCanvasDocument) -> Void) {
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        SwiftUI.withTransaction(transaction) {
            mutateCanvas(update)
        }
    }

    private func resetGestureOrigins() {
        dragOrigin = nil
        pinchOriginScale = nil
        rotateOriginDegrees = nil
    }

    private func canvasToolbarDidChange() {
        snapshotForUndo()
        design = CardCanvasSync.syncLegacyStyle(from: design)
    }

    private func applyResize(layerID: UUID, newSize: CGSize, cardSize: CGSize) {
        guard var layer = design.canvasDocument?.layer(id: layerID) else { return }
        layer.transform.width = max(0.04, Double(newSize.width / cardSize.width) / layer.transform.scale)
        layer.transform.height = max(0.04, Double(newSize.height / cardSize.height) / layer.transform.scale)
        mutateCanvasDuringGesture { $0.updateLayer(layer); $0.markCustomized() }
    }

    private func applyRotation(layerID: UUID, degrees: Double) {
        guard var layer = design.canvasDocument?.layer(id: layerID) else { return }
        layer.transform.rotation = BuxCanvasLayerTransformMath.snapRotation(degrees)
        mutateCanvasDuringGesture { $0.updateLayer(layer) }
    }

    private func handleCanvasTap(at location: CGPoint, cardSize: CGSize) {
        let nx = location.x / cardSize.width
        let ny = location.y / cardSize.height
        if let hit = CardCanvasHitTester.hitTest(point: CGPoint(x: nx, y: ny), in: document) {
            selectedID = hit
            backgroundSelected = false
            resetGestureOrigins()
        } else {
            selectedID = nil
            backgroundSelected = true
            resetGestureOrigins()
        }
    }

    // MARK: - Photo Lab & Focal

    private func loadImage(forLayerID id: UUID) -> UIImage? {
        guard let layer = design.canvasDocument?.layer(id: id),
              case .image(let payload) = layer.payload else { return nil }
        return loadImage(for: payload.source, assetPath: payload.assetPath)
    }

    private func loadImage(forFocalTarget target: BuxFocalEditorTarget) -> UIImage? {
        switch target {
        case .background:
            return SimpleStudioScanImageStore.load(path: design.canvasDocument?.background.photoPath)
        case .imageLayer(let id):
            return loadImage(forLayerID: id)
        }
    }

    private func loadImage(for source: CardImageSource, assetPath: String?) -> UIImage? {
        switch source {
        case .profilePhoto: return SimpleStudioScanImageStore.load(path: design.content.photoPath)
        case .profileLogo: return logoData.flatMap { UIImage(data: $0) }
        case .assetPath(let path): return SimpleStudioScanImageStore.load(path: path)
        }
    }

    private func focalTitle(for target: BuxFocalEditorTarget) -> String {
        switch target {
        case .background: return "Bux Background Focal"
        case .imageLayer: return "Bux Focal Crop"
        }
    }

    private func focalIsCircle(for target: BuxFocalEditorTarget) -> Bool {
        guard case .imageLayer(let id) = target,
              let layer = design.canvasDocument?.layer(id: id),
              case .image(let p) = layer.payload else { return false }
        return p.mask == .circle
    }

    private func applyPhotoStudioResult(_ result: BuxPhotoStudioResult, layerID: UUID?) {
        guard let id = layerID ?? (ifCaseCanvasLayer(result.target)),
              var layer = design.canvasDocument?.layer(id: id),
              case .image(var payload) = layer.payload else { return }
        if payload.source == .profilePhoto,
           let path = SimpleStudioScanImageStore.saveBusinessCardPhoto(result.image) {
            design.content.photoPath = path
        } else if payload.source == .profileLogo,
                  let data = result.image.jpegData(compressionQuality: 0.92) {
            // Canvas logo edits stay on layer asset path when not studio logo
            if let path = SimpleStudioScanImageStore.save(result.image, id: UUID()) {
                payload.assetPath = path
                payload.source = .assetPath(path)
            }
            _ = data
        } else if let path = SimpleStudioScanImageStore.save(result.image, id: UUID()) {
            payload.assetPath = path
        }
        payload.adjustments = result.adjustments
        payload.photoTransform = result.transform
        payload.mask = result.mask
        layer.payload = .image(payload)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
        if payload.source == .profilePhoto {
            design.style.photoAdjustments = result.adjustments
            design.style.photoTransform = result.transform
            design.style.photoMask = result.mask
        }
        if payload.source == .profileLogo {
            design.style.logoMask = result.mask
        }
        canvasToolbarDidChange()
    }

    private func ifCaseCanvasLayer(_ target: BuxPhotoStudioTarget) -> UUID? {
        if case .canvasLayer(let id) = target { return id }
        return nil
    }

    private var focalTransformBinding: Binding<ProBusinessCardPhotoTransform> {
        Binding(
            get: {
                switch focalTarget {
                case .background:
                    return design.canvasDocument?.background.photoTransform ?? ProBusinessCardPhotoTransform()
                case .imageLayer(let id):
                    if let layer = design.canvasDocument?.layer(id: id),
                       case .image(let p) = layer.payload { return p.photoTransform }
                    return ProBusinessCardPhotoTransform()
                case .none:
                    return ProBusinessCardPhotoTransform()
                }
            },
            set: { newValue in
                switch focalTarget {
                case .background:
                    mutateCanvas { doc in
                        doc.background.photoTransform = newValue
                        doc.markCustomized()
                    }
                    design.style.photoTransform = newValue
                case .imageLayer(let id):
                    mutateCanvas { doc in
                        guard var layer = doc.layer(id: id),
                              case .image(var p) = layer.payload else { return }
                        p.photoTransform = newValue
                        layer.payload = .image(p)
                        doc.updateLayer(layer)
                        doc.markCustomized()
                    }
                case .none:
                    break
                }
            }
        )
    }

    // MARK: - Bindings & undo

    private var selectedLayer: CardCanvasLayer? {
        guard let id = selectedID else { return nil }
        return design.canvasDocument?.layer(id: id)
    }

    private var canvasBinding: Binding<CardCanvasDocument> {
        Binding(
            get: { design.canvasDocument ?? CardCanvasMigrator.migrate(from: design) },
            set: { newDoc in
                var updated = design
                updated.canvasDocument = newDoc
                updated.updatedAt = Date()
                design = updated
            }
        )
    }

    private var backgroundBinding: Binding<CardBackgroundSpec> {
        Binding(
            get: {
                design.canvasDocument?.background ?? CardBackgroundSpec(
                    solidHex: design.palette.backgroundHex,
                    accentHex: design.palette.accentHex
                )
            },
            set: { newValue in
                applyBackgroundFromPhotoEditor(newValue)
            }
        )
    }

    /// One write to `design` — nested field assignments on `@Binding` drop `photoPath` (flash then vanish).
    private func applyBackgroundFromPhotoEditor(_ spec: CardBackgroundSpec) {
        var updated = design
        updated.ensureCanvasDocument()
        guard var doc = updated.canvasDocument else { return }
        doc.background = spec
        doc.markCustomized()
        updated.canvasDocument = doc
        updated.style.backgroundStyle = spec.style
        updated.style.backgroundPhotoPath = spec.photoPath
        updated.style.backgroundPhotoOpacity = spec.photoOpacity
        updated.palette.backgroundHex = spec.solidHex
        updated.palette.accentHex = spec.accentHex
        updated.updatedAt = Date()
        design = updated
    }

    private func applyCardAspectFromPhotoEditor(_ newAspect: ProBusinessCardAspect) {
        guard design.aspect != newAspect else { return }
        var updated = design
        updated.aspect = newAspect
        if var doc = updated.canvasDocument {
            let size = newAspect.previewSize
            doc.canvasWidth = Double(size.width)
            doc.canvasHeight = Double(size.height)
            updated.canvasDocument = doc
        }
        updated.updatedAt = Date()
        design = updated
    }

    private func snapshotForUndo() {
        if let doc = design.canvasDocument { undoManager.snapshot(doc) }
        CardCanvasSync.applyContentBindings(to: &design)
    }

    private func undo() {
        guard let doc = design.canvasDocument, let prev = undoManager.undo(current: doc) else { return }
        design.canvasDocument = prev
        design = CardCanvasSync.syncLegacyStyle(from: design)
        resetGestureOrigins()
    }

    private func redo() {
        guard let doc = design.canvasDocument, let next = undoManager.redo(current: doc) else { return }
        design.canvasDocument = next
        design = CardCanvasSync.syncLegacyStyle(from: design)
        resetGestureOrigins()
    }

    private func canvasToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            BuxCatalogText.text(title)
                .font(.system(size: 12, weight: .medium))
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private func exitAndDismiss() {
        design.ensureCanvasDocument()
        design = CardCanvasSync.syncLegacyStyle(from: design)
        design.editorPreferences = CardEditorPreferences(showSafeZone: showSafeZone, showSnapGuides: showSnapGuides)
        design.updatedAt = Date()
        onExit()
        dismiss()
    }

    private func applyInlineEdit(layerID: UUID) {
        guard var layer = design.canvasDocument?.layer(id: layerID),
              case .text(var payload) = layer.payload else { return }
        payload.text = inlineEditText
        if payload.binding != .none { syncBindingToContent(payload.binding, text: inlineEditText) }
        layer.payload = .text(payload)
        design.canvasDocument?.updateLayer(layer)
        design.canvasDocument?.markCustomized()
        inlineEditLayerID = nil
        snapshotForUndo()
    }

    private func syncBindingToContent(_ binding: CardTextContentBinding, text: String) {
        switch binding {
        case .name: design.content.name = text
        case .tagline: design.content.tagline = text
        case .phone: design.content.phone = text
        case .email: design.content.email = text
        case .website: design.content.website = text
        case .skills: design.content.skills = text
        case .none: break
        }
    }

    private func addTextLayer() {
        mutateCanvas { doc in
            let layer = CardCanvasLayer(
                name: "Text",
                kind: .text,
                transform: CardLayerTransform(centerX: 0.5, centerY: 0.5, width: 0.55, height: 0.1),
                payload: .text(CardTextPayload(text: "New text", style: CardTextStyle(colorHex: design.palette.foregroundHex)))
            )
            doc.layers.append(layer)
            doc.markCustomized()
            selectedID = layer.id
            backgroundSelected = false
        }
        snapshotForUndo()
    }

    private func snapGuides(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(themeManager.current.accentColor.opacity(0.18))
                .frame(width: 1, height: height)
            Rectangle()
                .fill(themeManager.current.accentColor.opacity(0.18))
                .frame(width: width, height: 1)
        }
    }

    private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}
