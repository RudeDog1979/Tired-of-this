//
//  BuxCardBackgroundPhotoEditorView.swift
//  BuxMuse — background photo: pan/zoom, card crop, free region (iOS 18+)
//

import SwiftUI
import UIKit

enum BuxCardBackgroundPhotoMode: String, CaseIterable, Identifiable {
    case fillCard = "Pan & zoom"
    case cropToCard = "Crop to card"
    case freeRegion = "Free region"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .fillCard:
            return "Pinch and drag the photo inside the card frame."
        case .cropToCard:
            return "Line up the white frame, then tap Apply."
        case .freeRegion:
            return "Resize the box and drag the photo, then tap Apply."
        }
    }
}

struct BuxCardBackgroundPhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let initialAspect: ProBusinessCardAspect
    let image: UIImage
    let initialBackground: CardBackgroundSpec
    let paperColorHex: String
    let onCommitAspect: (ProBusinessCardAspect) -> Void
    /// Parent must persist in one assignment — never rely on nested Binding writes to `design`.
    let onApply: (CardBackgroundSpec) -> Void

    @State private var editingAspect: ProBusinessCardAspect
    @State private var workingBackground: CardBackgroundSpec
    @State private var mode: BuxCardBackgroundPhotoMode = .fillCard

    init(
        initialAspect: ProBusinessCardAspect,
        image: UIImage,
        initialBackground: CardBackgroundSpec,
        paperColorHex: String,
        onCommitAspect: @escaping (ProBusinessCardAspect) -> Void,
        onApply: @escaping (CardBackgroundSpec) -> Void
    ) {
        self.initialAspect = initialAspect
        self.image = image
        self.initialBackground = initialBackground
        self.paperColorHex = paperColorHex
        self.onCommitAspect = onCommitAspect
        self.onApply = onApply
        _editingAspect = State(initialValue: initialAspect)
        _workingBackground = State(initialValue: initialBackground)
    }
    @State private var fillScale: CGFloat = 1
    @State private var fillRotation: Double = 0
    @State private var fillOffset: CGSize = .zero
    @State private var fillLastScale: CGFloat = 1
    @State private var fillLastOffset: CGSize = .zero
    @State private var fillCommitted: ProBusinessCardPhotoTransform = ProBusinessCardPhotoTransform()

    @State private var undoStack: [ProBusinessCardPhotoTransform] = []
    @State private var redoStack: [ProBusinessCardPhotoTransform] = []
    @State private var sessionBaseline: ProBusinessCardPhotoTransform = ProBusinessCardPhotoTransform()

    @State private var cropScale: CGFloat = 1
    @State private var cropOffset: CGSize = .zero

    @State private var freeScale: CGFloat = 1
    @State private var freeOffset: CGSize = .zero
    @State private var freeSelectionScale: CGFloat = 0.72
    @State private var freeRegionSessionID = UUID()

    @State private var applyErrorMessage: String?

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var cardFrameSize: CGSize {
        let maxW = min(340, UIScreen.main.bounds.width - 40)
        let ratio = editingAspect.aspectRatio
        if ratio >= 1 {
            return CGSize(width: maxW, height: maxW / ratio)
        }
        return CGSize(width: maxW * ratio, height: maxW)
    }

    private var cropViewportSide: CGFloat { min(340, UIScreen.main.bounds.width - 40) }

    private var cropFrameSize: CGSize {
        let side = min(260, cropViewportSide - 24)
        let ratio = editingAspect.aspectRatio
        if ratio >= 1 {
            return CGSize(width: side, height: side / ratio)
        }
        return CGSize(width: side * ratio, height: side)
    }

    private var cropCornerRadius: CGFloat { editingAspect == .squareSocial ? 20 : 14 }

    private var cropShape: ImageCropShape {
        .aspectFill(ratio: editingAspect.aspectRatio, cornerRadius: cropCornerRadius)
    }

    private var canUndo: Bool { !undoStack.isEmpty }
    private var canRedo: Bool { !redoStack.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlsHeader
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                editorStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, BuxTokens.marginRegular)

                controlsFooter
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.bottom, 12)
            }
            .background(themeManager.screenBackground(for: colorScheme))
            .buxCatalogNavigationTitle("Background photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: applyCurrentMode)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                workingBackground = initialBackground
                seedSession()
            }
            .onChange(of: mode) { oldMode, newMode in
                guard newMode == .freeRegion else { return }
                freeRegionSessionID = UUID()
                switch oldMode {
                case .cropToCard:
                    freeScale = cropScale
                    freeOffset = cropOffset
                case .fillCard:
                    freeScale = fillScale
                    freeOffset = fillOffset
                case .freeRegion:
                    break
                }
            }
        }
        .buxRootBrandTheme()
        .interactiveDismissDisabled()
    }

    // MARK: - Header (card size + mode — no ScrollView)

    private var controlsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                BuxCatalogDynamicText(key: "Card size")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                StudioGlassHorizontalSectionMenu(
                    selection: $editingAspect,
                    tabs: Array(ProBusinessCardAspect.allCases),
                    label: { "\($0.title) · \($0.detail)" }
                )
                .environmentObject(themeManager)
            }
            .padding(BuxTokens.marginRegular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buxFormSectionCard()

            Picker("Mode", selection: $mode) {
                ForEach(BuxCardBackgroundPhotoMode.allCases) { m in
                    Text(m.catalogLabel(locale: BuxInterfaceLocale.currentInterfaceLocale)).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Text(mode.detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            if let applyErrorMessage {
                Text(applyErrorMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private var editorStage: some View {
        switch mode {
        case .fillCard:
            ZStack {
                Color.black.opacity(0.9)
                BuxPhotoFocalStage(
                    image: image,
                    scale: $fillScale,
                    rotation: $fillRotation,
                    offset: $fillOffset,
                    lastScale: $fillLastScale,
                    lastOffset: $fillLastOffset,
                    viewportSize: cardFrameSize,
                    cornerRadius: cropCornerRadius,
                    onGestureEnded: recordFillEditForUndo
                )
            }
            .frame(width: cardFrameSize.width + 24, height: cardFrameSize.height + 24)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .cropToCard:
            ImageCropEditorContent(
                inputImage: image,
                cropShape: cropShape,
                scale: $cropScale,
                offset: $cropOffset,
                viewportSize: cropViewportSide,
                cropSize: cropFrameSize.width
            )
            .environmentObject(themeManager)
        case .freeRegion:
            BuxFreeformRegionCropView(
                image: image,
                cardAspect: editingAspect,
                cornerRadius: cropCornerRadius,
                selectionScale: freeSelectionScale,
                sessionID: freeRegionSessionID,
                scale: $freeScale,
                offset: $freeOffset
            )
            .id(freeRegionSessionID)
        }
    }

    @ViewBuilder
    private var controlsFooter: some View {
        switch mode {
        case .fillCard:
            VStack(spacing: 10) {
                editHistoryButtonRow
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                        Slider(value: $fillScale, in: 1...5)
                            .tint(controlTint)
                        Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "rotate.left").foregroundStyle(.secondary)
                        Slider(value: $fillRotation, in: -180...180)
                            .tint(controlTint)
                        Image(systemName: "rotate.right").foregroundStyle(.secondary)
                    }
                }
                BuxCatalogDynamicText(key: "Drag to reposition · pinch or slide to zoom")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        case .cropToCard:
            EmptyView()
        case .freeRegion:
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogDynamicText(key: "Selection size")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Slider(value: $freeSelectionScale, in: 0.35...1)
                        .tint(controlTint)
                }
                Button("Reset selection") { resetFreeformSession() }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(controlTint)
            }
        }
    }

    private var editHistoryButtonRow: some View {
        HStack(spacing: 8) {
            historyButton("Undo", icon: "arrow.uturn.backward", enabled: canUndo, action: undoEdit)
            historyButton("Redo", icon: "arrow.uturn.forward", enabled: canRedo, action: redoEdit)
            historyButton("Reset", icon: "arrow.counterclockwise", enabled: true, action: resetEdit)
        }
    }

    private func historyButton(_ title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
        .buttonStyle(.bordered)
        .tint(controlTint)
    }

    private func seedSession() {
        applyTransformToFillUI(workingBackground.photoTransform)
        sessionBaseline = workingBackground.photoTransform
        fillCommitted = workingBackground.photoTransform
    }

    private func applyTransformToFillUI(_ value: ProBusinessCardPhotoTransform) {
        fillScale = max(1, CGFloat(value.zoom))
        fillLastScale = fillScale
        fillRotation = value.rotation
        fillOffset = CGSize(
            width: CGFloat(value.offsetX) * cardFrameSize.width,
            height: CGFloat(value.offsetY) * cardFrameSize.height
        )
        fillLastOffset = fillOffset
    }

    private func fillTransformSnapshot() -> ProBusinessCardPhotoTransform {
        ProBusinessCardPhotoTransform(
            zoom: Double(fillScale),
            offsetX: Double(fillOffset.width / max(1, cardFrameSize.width)),
            offsetY: Double(fillOffset.height / max(1, cardFrameSize.height)),
            rotation: fillRotation
        )
    }

    private func recordFillEditForUndo() {
        pushUndoSnapshot(before: fillCommitted)
        fillCommitted = fillTransformSnapshot()
    }

    private func resetFreeformSession() {
        freeScale = 1
        freeOffset = .zero
        freeSelectionScale = 0.72
    }

    private func freeSelectionFrame(in viewport: CGSize) -> CGSize {
        let ratio = editingAspect.aspectRatio
        if ratio >= 1 {
            let w = viewport.width * freeSelectionScale
            return CGSize(width: w, height: w / ratio)
        }
        let h = viewport.height * freeSelectionScale
        return CGSize(width: h * ratio, height: h)
    }

    private func applyCurrentMode() {
        applyErrorMessage = nil
        switch mode {
        case .fillCard:
            applyFillMode()
        case .cropToCard:
            let viewport = CGSize(width: cropViewportSide, height: cropViewportSide)
            guard let cropped = ImageCropRenderer.croppedImage(
                inputImage: image,
                scale: cropScale,
                offset: cropOffset,
                viewportSize: viewport,
                cropFrameSize: cropFrameSize,
                cornerRadius: cropCornerRadius,
                exportSize: editingAspect.printSize,
                paperColorHex: paperColorHex
            ) else {
                applyErrorMessage = "Crop failed — adjust zoom/position and try again."
                return
            }
            applyCroppedImage(cropped)
        case .freeRegion:
            let viewport = freeRegionViewport
            let selection = freeSelectionFrame(in: viewport)
            guard let cropped = ImageCropRenderer.croppedImage(
                inputImage: image,
                scale: freeScale,
                offset: freeOffset,
                viewportSize: viewport,
                cropFrameSize: selection,
                cornerRadius: cropCornerRadius,
                exportSize: editingAspect.printSize,
                paperColorHex: paperColorHex
            ) else {
                applyErrorMessage = "Export failed — adjust the selection and try again."
                return
            }
            applyCroppedImage(cropped)
        }
    }

    private var freeRegionViewport: CGSize {
        let maxW = min(340, UIScreen.main.bounds.width - 40)
        return CGSize(width: maxW, height: min(400, maxW * 1.12))
    }

    private func pushUndoSnapshot(before previous: ProBusinessCardPhotoTransform) {
        undoStack.append(previous)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func undoEdit() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(fillCommitted)
        applyTransformFromHistory(previous)
    }

    private func redoEdit() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(fillCommitted)
        applyTransformFromHistory(next)
    }

    private func resetEdit() {
        pushUndoSnapshot(before: fillCommitted)
        applyTransformFromHistory(sessionBaseline)
    }

    private func applyTransformFromHistory(_ value: ProBusinessCardPhotoTransform) {
        applyTransformToFillUI(value)
        fillCommitted = value
    }

    private func commitBackground(_ update: (inout CardBackgroundSpec) -> Void) {
        var spec = workingBackground
        update(&spec)
        workingBackground = spec
    }

    private func applyFillMode() {
        guard let path = SimpleStudioScanImageStore.save(image, id: UUID()),
              SimpleStudioScanImageStore.load(path: path) != nil else {
            applyErrorMessage = "Could not save photo to disk."
            return
        }
        commitBackground { bg in
            bg.photoPath = path
            bg.style = .photo
            bg.photoTransform = fillTransformSnapshot()
            bg.photoOpacity = max(bg.photoOpacity, 0.85)
        }
        finishCommit()
    }

    private func applyCroppedImage(_ cropped: UIImage) {
        guard let path = SimpleStudioScanImageStore.save(cropped, id: UUID()),
              SimpleStudioScanImageStore.load(path: path) != nil else {
            applyErrorMessage = "Could not save cropped photo."
            return
        }
        commitBackground { bg in
            bg.photoPath = path
            bg.style = .photo
            bg.photoTransform = ProBusinessCardPhotoTransform()
            bg.photoOpacity = 1
        }
        finishCommit()
    }

    private func finishCommit() {
        onCommitAspect(editingAspect)
        onApply(workingBackground)
        dismiss()
    }
}

// MARK: - Freeform (UIKit pan/pinch — bindings update on gesture end only)

struct BuxFreeformRegionCropView: View {
    let image: UIImage
    let cardAspect: ProBusinessCardAspect
    let cornerRadius: CGFloat
    let selectionScale: CGFloat
    let sessionID: UUID
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    private var viewport: CGSize {
        let maxW = min(340, UIScreen.main.bounds.width - 40)
        return CGSize(width: maxW, height: min(400, maxW * 1.12))
    }

    private var selectionFrame: CGSize {
        let ratio = cardAspect.aspectRatio
        if ratio >= 1 {
            let w = viewport.width * selectionScale
            return CGSize(width: w, height: w / ratio)
        }
        let h = viewport.height * selectionScale
        return CGSize(width: h * ratio, height: h)
    }

    var body: some View {
        BuxFreeformPhotoEditorRepresentable(
            image: image,
            viewport: viewport,
            selectionSize: selectionFrame,
            cornerRadius: cornerRadius,
            sessionID: sessionID,
            scale: $scale,
            offset: $offset
        )
        .frame(width: viewport.width, height: viewport.height)
        .fixedSize()
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct BuxFreeformPhotoEditorRepresentable: UIViewRepresentable {
    let image: UIImage
    let viewport: CGSize
    let selectionSize: CGSize
    let cornerRadius: CGFloat
    let sessionID: UUID
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> BuxFreeformPhotoUIView {
        let view = BuxFreeformPhotoUIView()
        view.onTransformEnded = { scale, offset in
            context.coordinator.commit(scale: scale, offset: offset)
        }
        view.prepareForSession(sessionID)
        return view
    }

    func updateUIView(_ uiView: BuxFreeformPhotoUIView, context: Context) {
        context.coordinator.parent = self
        uiView.prepareForSession(sessionID)
        uiView.apply(
            image: image,
            selectionSize: selectionSize,
            cornerRadius: cornerRadius,
            scale: scale,
            offset: offset
        )
        if uiView.bounds.width < 1 || uiView.bounds.height < 1 {
            DispatchQueue.main.async {
                uiView.setNeedsLayout()
                uiView.layoutIfNeeded()
            }
        }
    }

    final class Coordinator {
        var parent: BuxFreeformPhotoEditorRepresentable
        init(_ parent: BuxFreeformPhotoEditorRepresentable) { self.parent = parent }

        func commit(scale: CGFloat, offset: CGSize) {
            guard parent.scale != scale || parent.offset != offset else { return }
            parent.scale = scale
            parent.offset = offset
        }
    }
}

final class BuxFreeformPhotoUIView: UIView, UIGestureRecognizerDelegate {
    var onTransformEnded: ((CGFloat, CGSize) -> Void)?

    private let imageView = UIImageView()
    private let overlayLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    private var selectionSize: CGSize = .zero
    private var holeRadius: CGFloat = 14
    private var currentScale: CGFloat = 1
    private var currentOffset: CGSize = .zero
    private var pinchStart: CGFloat = 1
    private var panStart: CGSize = .zero

    private var activeSessionID: UUID?
    private var appliedImageID: ObjectIdentifier?
    private var appliedSelection: CGSize = .zero
    private var appliedCornerRadius: CGFloat = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = UIColor.black.withAlphaComponent(0.88)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        overlayLayer.fillRule = .evenOdd
        overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        layer.addSublayer(overlayLayer)

        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 2
        layer.addSublayer(borderLayer)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 2
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func prepareForSession(_ sessionID: UUID) {
        guard activeSessionID != sessionID else { return }
        activeSessionID = sessionID
        appliedImageID = nil
        appliedSelection = .zero
        appliedCornerRadius = -1
        currentScale = 1
        currentOffset = .zero
        pinchStart = 1
        panStart = .zero
    }

    func apply(
        image: UIImage,
        selectionSize: CGSize,
        cornerRadius: CGFloat,
        scale: CGFloat,
        offset: CGSize
    ) {
        self.selectionSize = selectionSize
        self.holeRadius = cornerRadius
        currentScale = scale
        currentOffset = offset
        pinchStart = scale
        panStart = offset

        let imageID = ObjectIdentifier(image)
        if appliedImageID != imageID {
            appliedImageID = imageID
            imageView.image = image.normalizedImage()
        }

        if bounds.width > 0, bounds.height > 0 {
            layoutImage()
        }

        if appliedSelection != selectionSize || appliedCornerRadius != cornerRadius {
            appliedSelection = selectionSize
            appliedCornerRadius = cornerRadius
            updateMask()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 340, height: 400)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else { return nil }
        return self
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutImage()
        updateMask()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func layoutImage() {
        guard let img = imageView.image else { return }
        let fit = min(bounds.width / img.size.width, bounds.height / img.size.height)
        let w = img.size.width * fit * currentScale
        let h = img.size.height * fit * currentScale
        imageView.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        imageView.center = CGPoint(
            x: bounds.midX + currentOffset.width,
            y: bounds.midY + currentOffset.height
        )
    }

    private func updateMask() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let outer = UIBezierPath(rect: bounds)
        let origin = CGPoint(
            x: (bounds.width - selectionSize.width) / 2,
            y: (bounds.height - selectionSize.height) / 2
        )
        let holeRect = CGRect(origin: origin, size: selectionSize)
        let hole = UIBezierPath(roundedRect: holeRect, cornerRadius: holeRadius)
        outer.append(hole)
        overlayLayer.path = outer.cgPath
        borderLayer.path = hole.cgPath
    }

    private func emitIfEnded() {
        onTransformEnded?(currentScale, currentOffset)
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            pinchStart = currentScale
        case .changed:
            currentScale = min(4, max(1, pinchStart * g.scale))
            layoutImage()
        case .ended, .cancelled:
            emitIfEnded()
        default:
            break
        }
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            panStart = currentOffset
        case .changed:
            let t = g.translation(in: self)
            currentOffset = CGSize(width: panStart.width + t.x, height: panStart.height + t.y)
            layoutImage()
        case .ended, .cancelled:
            emitIfEnded()
        default:
            break
        }
    }
}

