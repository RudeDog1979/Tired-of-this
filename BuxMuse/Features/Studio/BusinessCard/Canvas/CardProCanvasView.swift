//
//  CardProCanvasView.swift
//  BuxMuse
//
//  Bux Canvas — full-screen proprietary card editor (BuxMuse).
//

import SwiftUI

struct CardProCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var design: ProBusinessCardDesign
    let logoData: Data?
    let onSave: () -> Void
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
            onLayerDuplicated: { selectedID = $0 },
            onLayerDeleted: { selectedID = nil }
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                CardFloatingToolbar(
                    layer: selectedLayer,
                    backgroundSelected: backgroundSelected,
                    document: canvasBinding,
                    actions: toolbarActions,
                    onChange: { canvasToolbarDidChange() }
                )
                .padding(.top, 8)
                canvasWorkspace
                bottomRail
            }

            if let editID = inlineEditLayerID {
                inlineTextOverlay(layerID: editID)
            }
        }
        .onAppear {
            design.ensureCanvasDocument()
            CardCanvasSync.syncLogoFromStudio(to: &design, logoData: logoData)
            if let doc = design.canvasDocument { undoManager.snapshot(doc) }
            showSafeZone = design.editorPreferences?.showSafeZone ?? true
            showSnapGuides = design.editorPreferences?.showSnapGuides ?? true
        }
        .sheet(isPresented: $showLayerPanel) {
            NavigationStack {
                CardLayerPanel(
                    document: canvasBinding,
                    selectedID: $selectedID,
                    backgroundSelected: $backgroundSelected,
                    onChange: { canvasToolbarDidChange() }
                )
                    .navigationTitle("Bux Layers")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showLayerPanel = false } } }
            }
        }
        .sheet(isPresented: $showBackgroundEditor) {
            NavigationStack {
                CardBackgroundEditor(
                    background: backgroundBinding,
                    onPickPhoto: { onPickBackgroundPhoto?() },
                    onOpenFocal: {
                        showBackgroundEditor = false
                        guard let img = SimpleStudioScanImageStore.load(path: design.canvasDocument?.background.photoPath) else { return }
                        focalTarget = .background
                        focalSession = BuxFocalSession(
                            target: .background,
                            image: img,
                            title: "Bux Background Focal",
                            cropIsCircle: false
                        )
                    },
                    onChange: { snapshotForUndo() }
                )
                .navigationTitle("Bux Background")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showBackgroundEditor = false } } }
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
                cropIsCircle: session.cropIsCircle
            ) {
                snapshotForUndo()
            }
            .environmentObject(themeManager)
            .onAppear { focalTarget = session.target }
        }
        .sheet(isPresented: $showShapePicker) {
            BuxShapePickerSheet(
                palette: design.palette,
                onPickShape: { addShapeLayer($0) },
                onApplyPack: { applyLayoutPack($0) }
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!undoManager.canUndo)
            Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!undoManager.canRedo)
            Spacer()
            Text("Bux Canvas")
                .font(.system(size: 15, weight: .bold))
            Spacer()
            Button("Save") { commitAndDismiss() }
                .fontWeight(.semibold)
                .foregroundStyle(themeManager.current.accentColor)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.35))
    }

    private var canvasWorkspace: some View {
        GeometryReader { geo in
            let cardSize = design.aspect.previewSize
            let baseFit = min((geo.size.width - 32) / cardSize.width, (geo.size.height - 32) / cardSize.height, 1.4)
            let fittedW = cardSize.width * baseFit * workspaceScale
            let fittedH = cardSize.height * baseFit * workspaceScale
            let canPanWorkspace = selectedID == nil && !backgroundSelected

            ZStack {
                if canPanWorkspace {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(workspacePanGesture)
                        .simultaneousGesture(workspacePinchGesture)
                }

                if showSnapGuides {
                    snapGuides(width: fittedW, height: fittedH)
                        .offset(workspacePan)
                        .allowsHitTesting(false)
                }

                ZStack {
                    if backgroundSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(themeManager.current.accentColor, lineWidth: 2.5)
                            .frame(width: cardSize.width, height: cardSize.height)
                            .allowsHitTesting(false)
                    }

                    if let ctx = CardCanvasRenderContext.make(design: design, logoData: logoData) {
                        CardCanvasRenderer(
                            context: ctx,
                            selectedLayerID: backgroundSelected ? nil : selectedID,
                            showSafeZone: showSafeZone,
                            interactive: false
                        )
                        .allowsHitTesting(false)
                    }

                    canvasInteractionOverlay(cardSize: cardSize)
                }
                .frame(width: cardSize.width, height: cardSize.height)
                .scaleEffect(baseFit * workspaceScale)
                .offset(workspacePan)
                .frame(width: fittedW, height: fittedH)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func canvasInteractionOverlay(cardSize: CGSize) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleCanvasTap(at: location, cardSize: cardSize)
                }
                .gesture(layerMoveGesture(cardSize: cardSize))

            if let layer = selectedLayer, !layer.isLocked {
                let frame = layer.transform.frame(in: cardSize)
                BuxCanvasSelectionChrome(
                    frame: frame,
                    accent: themeManager.current.accentColor,
                    rotation: layer.transform.rotation,
                    onResize: { newSize in applyResize(layerID: layer.id, newSize: newSize, cardSize: cardSize) },
                    onResizeEnd: { canvasToolbarDidChange() },
                    onRotate: { applyRotation(layerID: layer.id, degrees: $0) },
                    onRotateEnd: { canvasToolbarDidChange() }
                )
            }
        }
    }

    private func layerMoveGesture(cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { v in
                guard let id = selectedID,
                      var layer = design.canvasDocument?.layer(id: id),
                      !layer.isLocked else { return }
                if dragOrigin == nil { dragOrigin = layer.transform }
                guard let origin = dragOrigin else { return }
                layer.transform.centerX = clamp(origin.centerX + Double(v.translation.width / cardSize.width))
                layer.transform.centerY = clamp(origin.centerY + Double(v.translation.height / cardSize.height))
                mutateCanvas { $0.updateLayer(layer) }
            }
            .onEnded { _ in
                dragOrigin = nil
                mutateCanvas { $0.markCustomized() }
                canvasToolbarDidChange()
            }
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

    private var bottomRail: some View {
        VStack(spacing: 8) {
            if let doc = design.canvasDocument {
                BuxCanvasElementsStrip(
                    layers: doc.layers,
                    selectedID: $selectedID,
                    backgroundSelected: $backgroundSelected,
                    onSelect: { _ in dragOrigin = nil }
                )
            }

            HStack(spacing: 12) {
                railButton("Layers", icon: "square.3.layers.3d") { showLayerPanel = true }
                railButton("Background", icon: "photo.fill.on.rectangle.fill") {
                    backgroundSelected = true
                    selectedID = nil
                }
                railButton("Add text", icon: "text.badge.plus") { addTextLayer() }
                railButton("Shapes", icon: "triangle.fill") { showShapePicker = true }
            }

            HStack(spacing: 12) {
                railButton("Reset zoom", icon: "arrow.counterclockwise") {
                    workspaceScale = 1
                    lastWorkspaceScale = 1
                    workspacePan = .zero
                    lastWorkspacePan = .zero
                }
                Button(action: { commitAndDismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to Studio")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.current.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack {
                Toggle("Safe zone", isOn: $showSafeZone).tint(themeManager.current.accentColor)
                Toggle("Snap", isOn: $showSnapGuides).tint(themeManager.current.accentColor)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))

            Text("Tap element below · drag to move · top handle to rotate · Save when done")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(.black.opacity(0.45))
    }

    private func railButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func inlineTextOverlay(layerID: UUID) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { inlineEditLayerID = nil }
            VStack(spacing: 12) {
                TextField("Edit text", text: $inlineEditText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    Button("Cancel") { inlineEditLayerID = nil }
                    Spacer()
                    Button("Apply") { applyInlineEdit(layerID: layerID) }
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
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

    private func canvasToolbarDidChange() {
        snapshotForUndo()
        design = CardCanvasSync.syncLegacyStyle(from: design)
    }

    private func applyResize(layerID: UUID, newSize: CGSize, cardSize: CGSize) {
        guard var layer = design.canvasDocument?.layer(id: layerID) else { return }
        layer.transform.width = max(0.04, Double(newSize.width / cardSize.width) / layer.transform.scale)
        layer.transform.height = max(0.04, Double(newSize.height / cardSize.height) / layer.transform.scale)
        mutateCanvas { $0.updateLayer(layer); $0.markCustomized() }
    }

    private func applyRotation(layerID: UUID, degrees: Double) {
        guard var layer = design.canvasDocument?.layer(id: layerID) else { return }
        layer.transform.rotation = degrees
        mutateCanvas { $0.updateLayer(layer) }
    }

    private func handleCanvasTap(at location: CGPoint, cardSize: CGSize) {
        let nx = location.x / cardSize.width
        let ny = location.y / cardSize.height
        if let hit = CardCanvasHitTester.hitTest(point: CGPoint(x: nx, y: ny), in: document) {
            selectedID = hit
            backgroundSelected = false
            dragOrigin = nil
        } else {
            selectedID = nil
            backgroundSelected = true
            dragOrigin = nil
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
            set: { design.canvasDocument = $0; design.updatedAt = Date() }
        )
    }

    private var backgroundBinding: Binding<CardBackgroundSpec> {
        Binding(
            get: { design.canvasDocument?.background ?? CardBackgroundSpec() },
            set: {
                design.canvasDocument?.background = $0
                design.style.backgroundStyle = $0.style
                design.style.backgroundPhotoPath = $0.photoPath
                design.style.backgroundPhotoOpacity = $0.photoOpacity
                design.palette.backgroundHex = $0.solidHex
                design.canvasDocument?.markCustomized()
                design.updatedAt = Date()
            }
        )
    }

    private func snapshotForUndo() {
        if let doc = design.canvasDocument { undoManager.snapshot(doc) }
        CardCanvasSync.applyContentBindings(to: &design)
    }

    private func undo() {
        guard let doc = design.canvasDocument, let prev = undoManager.undo(current: doc) else { return }
        design.canvasDocument = prev
        design = CardCanvasSync.syncLegacyStyle(from: design)
        dragOrigin = nil
    }

    private func redo() {
        guard let doc = design.canvasDocument, let next = undoManager.redo(current: doc) else { return }
        design.canvasDocument = next
        design = CardCanvasSync.syncLegacyStyle(from: design)
        dragOrigin = nil
    }

    private func commitAndDismiss() {
        design.ensureCanvasDocument()
        design = CardCanvasSync.syncLegacyStyle(from: design)
        design.editorPreferences = CardEditorPreferences(showSafeZone: showSafeZone, showSnapGuides: showSnapGuides)
        design.updatedAt = Date()
        onSave()
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
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: height)
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: width, height: 1)
        }
    }

    private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}
