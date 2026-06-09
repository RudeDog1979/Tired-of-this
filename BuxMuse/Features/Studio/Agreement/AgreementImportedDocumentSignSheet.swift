//
//  AgreementImportedDocumentSignSheet.swift
//  BuxMuse — Immersive full-screen tap-to-sign for imported agreements.
//

import PencilKit
import SwiftUI

struct AgreementImportedDocumentSignSheet: View {
    private enum EditorMode: String, CaseIterable, Identifiable {
        case sign
        case ink

        var id: String { rawValue }

        func catalogTitle(locale: Locale) -> String {
            switch self {
            case .sign: StudioAgreementL10n.line("Sign", locale: locale)
            case .ink: StudioAgreementL10n.line("Markup", locale: locale)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var draft: AgreementDraft
    let sourcePath: String
    let sourceKind: AgreementImportedSourceKind
    let pageCount: Int
    var initialRole: AgreementSignatureRole
    var onPersist: () -> Void

    @State private var pageIndex = 0
    @State private var drawing = PKDrawing()
    @State private var pageImage: UIImage?
    @State private var pageSize: CGSize = .zero
    @State private var layoutContainerSize: CGSize = .zero
    @State private var annotation = AgreementImportedPageAnnotation(pageSize: .zero)
    @State private var activeRole: AgreementSignatureRole
    @State private var editorMode: EditorMode = .sign
    @State private var pendingStampCenter: CGPoint?
    @State private var captureRole: AgreementSignatureRole?
    @State private var captureDrawing = PKDrawing()
    @State private var selectedPlacementID: UUID?
    @State private var draggingPlacementID: UUID?
    @State private var resizingPlacementID: UUID?
    @State private var transformAnchorNormalized: AgreementImportedNormalizedRect?
    @State private var viewportScale: CGFloat = 1
    @State private var viewportOffset: CGSize = .zero
    @State private var lastViewportScale: CGFloat = 1
    @State private var lastViewportOffset: CGSize = .zero

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var canMarkUpCurrentPage: Bool {
        AgreementImportedDocumentLimits.canMarkUp(pageIndex: pageIndex, pageCount: pageCount)
    }

    init(
        draft: Binding<AgreementDraft>,
        sourcePath: String,
        sourceKind: AgreementImportedSourceKind,
        pageCount: Int,
        initialRole: AgreementSignatureRole = .client,
        onPersist: @escaping () -> Void
    ) {
        _draft = draft
        self.sourcePath = sourcePath
        self.sourceKind = sourceKind
        self.pageCount = pageCount
        self.initialRole = initialRole
        self.onPersist = onPersist
        _activeRole = State(initialValue: initialRole)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            documentCanvas
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                Spacer(minLength: 0)
                if captureRole == nil {
                    bottomChrome
                }
            }

            if let captureRole {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { self.captureRole = nil }

                VStack {
                    Spacer()
                    AgreementImportedInlineSignaturePad(
                        role: captureRole,
                        drawing: $captureDrawing,
                        onCancel: {
                            self.captureRole = nil
                            captureDrawing = PKDrawing()
                        },
                        onSave: { png in
                            applyCapturedSignature(png, role: captureRole)
                            self.captureRole = nil
                            captureDrawing = PKDrawing()
                        }
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .buxInterfaceLocale()
        .onAppear(perform: loadPage)
        .onChange(of: pageIndex) { oldIndex, _ in
            savePage(at: oldIndex)
            loadPage()
        }
    }

    private var topChrome: some View {
        HStack(spacing: 12) {
            Button {
                saveCurrentPage()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.16))
                    .clipShape(Circle())
            }

            Text(
                StudioAgreementL10n.format(
                    "Page %d of %d",
                    locale: locale,
                    pageIndex + 1,
                    pageCount
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)

            Spacer(minLength: 8)

            if canMarkUpCurrentPage {
                topSignModeControls
            }

            Spacer(minLength: 8)

            if canMarkUpCurrentPage {
                Picker(StudioAgreementL10n.line("Signer", locale: locale), selection: $activeRole) {
                    Text(AgreementSignatureRole.client.catalogShortLabel(locale: locale))
                        .tag(AgreementSignatureRole.client)
                    Text(AgreementSignatureRole.provider.catalogShortLabel(locale: locale))
                        .tag(AgreementSignatureRole.provider)
                }
                .pickerStyle(.menu)
                .tint(.white)
                .frame(width: 88, alignment: .trailing)
                .opacity(editorMode == .sign ? 1 : 0)
                .disabled(editorMode != .sign)
                .accessibilityHidden(editorMode != .sign)
            }

            Button {
                saveCurrentPage()
                onPersist()
                BuxSaveFeedback.success()
                dismiss()
            } label: {
                BuxCatalogDynamicText(key: "Done")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.contrastAccentColor(for: colorScheme))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, BuxTokens.marginRegular)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.72), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var documentCanvas: some View {
        GeometryReader { proxy in
            if pageSize.width > 0, let pageImage {
                let fitted = AgreementImportedPageGeometry.aspectFitRect(
                    contentSize: pageSize,
                    in: proxy.size
                )

                ZStack {
                    pageInteractiveStack(pageImage: pageImage, fitSize: fitted.size)
                        .frame(width: fitted.width, height: fitted.height)
                        .scaleEffect(viewportScale)
                        .offset(viewportOffset)
                        .position(x: fitted.midX, y: fitted.midY)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture(count: 2) {
                    resetViewport()
                }
                .background {
                    Color.clear
                        .onAppear {
                            scheduleLayoutContainerSize(proxy.size)
                        }
                        .onChange(of: proxy.size) { _, newSize in
                            scheduleLayoutContainerSize(newSize)
                        }
                }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func pageInteractiveStack(pageImage: UIImage, fitSize: CGSize) -> some View {
        let localFit = CGRect(origin: .zero, size: fitSize)
        let allowsDocumentPan = selectedPlacementID == nil
            && draggingPlacementID == nil
            && resizingPlacementID == nil
            && captureRole == nil

        ZStack {
            ZStack {
                Image(uiImage: pageImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fitSize.width, height: fitSize.height)

                if editorMode == .ink, canMarkUpCurrentPage, captureRole == nil {
                    BuxPadPencilCanvasView(
                        drawing: $drawing,
                        drawingPolicy: .anyInput,
                        showsToolPicker: BuxPadIdiom.isPad,
                        inkColor: UIColor(themeManager.contrastAccentColor(for: colorScheme)),
                        inkWidth: 2.5
                    )
                    .frame(width: fitSize.width, height: fitSize.height)
                }

                if editorMode == .sign, canMarkUpCurrentPage, captureRole == nil {
                    Color.clear
                        .frame(width: fitSize.width, height: fitSize.height)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    handleSignTap(at: value.location, fitSize: fitSize)
                                }
                        )
                }
            }
            .frame(width: fitSize.width, height: fitSize.height)
            .contentShape(Rectangle())
            .gesture(allowsDocumentPan ? viewportPanGesture : nil)
            .simultaneousGesture(allowsDocumentPan ? viewportPinchGesture : nil)

            ForEach(annotation.signaturePlacements) { placement in
                signatureStampView(placement: placement, fitRect: localFit)
            }
        }
        .frame(width: fitSize.width, height: fitSize.height)
        .coordinateSpace(name: BuxCanvasLayerTransformMath.canvasCoordinateSpaceName)
    }

    private var viewportPanGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard captureRole == nil,
                      draggingPlacementID == nil,
                      resizingPlacementID == nil else { return }
                viewportOffset = CGSize(
                    width: lastViewportOffset.width + value.translation.width,
                    height: lastViewportOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastViewportOffset = viewportOffset
            }
    }

    private var viewportPinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard captureRole == nil,
                      selectedPlacementID == nil,
                      draggingPlacementID == nil else { return }
                viewportScale = min(5, max(1, lastViewportScale * value))
            }
            .onEnded { _ in
                lastViewportScale = viewportScale
            }
    }

    private func resetViewport() {
        viewportScale = 1
        viewportOffset = .zero
        lastViewportScale = 1
        lastViewportOffset = .zero
    }

    private var topSignModeControls: some View {
        HStack(spacing: 8) {
            Picker(StudioAgreementL10n.line("Mode", locale: locale), selection: $editorMode) {
                ForEach(EditorMode.allCases) { mode in
                    Text(mode.catalogTitle(locale: locale)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 156)
            .buxThemedSegmentedPicker()
            .colorScheme(.dark)

            Button(action: undoLastSignaturePlacement) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 32)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 32)
            .disabled(editorMode != .sign || annotation.signaturePlacements.isEmpty)
            .opacity(editorMode == .sign && !annotation.signaturePlacements.isEmpty ? 1 : 0.35)
            .accessibilityLabel(StudioAgreementL10n.line("Undo", locale: locale))
        }
        .frame(width: 200, alignment: .center)
    }

    private var bottomChrome: some View {
        VStack(spacing: 8) {
            if editorMode == .sign, canMarkUpCurrentPage {
                Text(
                    selectedPlacementID == nil
                        ? StudioAgreementL10n.line(
                            "Tap where you want to sign. Tap a signature to move or resize it.",
                            locale: locale
                        )
                        : StudioAgreementL10n.line(
                            "Drag to move. Corner boxes to resize. Top handle to rotate.",
                            locale: locale
                        )
                )
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, BuxTokens.marginRegular)
            }

            if editorMode == .ink, canMarkUpCurrentPage {
                HStack {
                    Spacer()
                    Button {
                        drawing = PKDrawing()
                    } label: {
                        Label {
                            BuxCatalogDynamicText(key: "Clear markup")
                        } icon: {
                            Image(systemName: "trash")
                        }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.55))
            }
        }
    }

    private func undoLastSignaturePlacement() {
        guard !annotation.signaturePlacements.isEmpty else { return }
        annotation.signaturePlacements.removeLast()
    }

    @ViewBuilder
    private func signatureStampView(
        placement: AgreementImportedSignaturePlacement,
        fitRect: CGRect
    ) -> some View {
        let rect = placement.normalizedRect.viewRect(in: fitRect)
        let isSelected = selectedPlacementID == placement.id
        let canManipulate = editorMode == .sign && captureRole == nil && canMarkUpCurrentPage
        let accent = themeManager.contrastAccentColor(for: colorScheme)

        if let role = placement.signatureRole,
           let image = signatureImage(for: role) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: rect.width, height: rect.height)
                    .rotationEffect(.degrees(placement.rotationDegrees))
                    .contentShape(Rectangle())
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(!isSelected)
                    .onTapGesture {
                        guard canManipulate else { return }
                        selectedPlacementID = placement.id
                    }

                if isSelected && canManipulate {
                    AgreementImportedSignatureSelectionChrome(
                        frame: rect,
                        accent: accent,
                        rotation: placement.rotationDegrees,
                        onMove: { delta in
                            handleStampMove(placementID: placement.id, delta: delta, fitRect: fitRect)
                        },
                        onMoveEnd: finishStampTransform,
                        onResize: { size in
                            handleStampResize(placementID: placement.id, size: size, fitRect: fitRect)
                        },
                        onResizeEnd: finishStampTransform,
                        onRotate: { degrees in
                            handleStampRotate(placementID: placement.id, degrees: degrees)
                        },
                        onRotateEnd: finishStampTransform
                    )
                }
            }
            .zIndex(isSelected ? 10 : 1)
            .onLongPressGesture {
                guard canManipulate else { return }
                annotation.signaturePlacements.removeAll { $0.id == placement.id }
                if selectedPlacementID == placement.id {
                    selectedPlacementID = nil
                }
            }
            .accessibilityLabel(role.catalogTitle(locale: locale))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func handleStampMove(placementID: UUID, delta: CGSize, fitRect: CGRect) {
        if transformAnchorNormalized == nil {
            guard let placement = annotation.signaturePlacements.first(where: { $0.id == placementID }) else { return }
            transformAnchorNormalized = placement.normalizedRect
            draggingPlacementID = placementID
            selectedPlacementID = placementID
        }
        guard let anchor = transformAnchorNormalized else { return }
        var viewRect = anchor.viewRect(in: fitRect)
        viewRect.origin.x += delta.width
        viewRect.origin.y += delta.height
        updatePlacement(placementID) { current in
            current.normalizedRect = AgreementImportedNormalizedRect.from(
                viewRect: viewRect,
                in: fitRect
            )
        }
    }

    private func handleStampResize(placementID: UUID, size: CGSize, fitRect: CGRect) {
        if transformAnchorNormalized == nil {
            guard let placement = annotation.signaturePlacements.first(where: { $0.id == placementID }) else { return }
            transformAnchorNormalized = placement.normalizedRect
            resizingPlacementID = placementID
            selectedPlacementID = placementID
        }
        guard let anchor = transformAnchorNormalized else { return }
        let anchorView = anchor.viewRect(in: fitRect)
        let center = CGPoint(x: anchorView.midX, y: anchorView.midY)
        let viewRect = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        updatePlacement(placementID) { current in
            current.normalizedRect = AgreementImportedNormalizedRect.from(
                viewRect: viewRect,
                in: fitRect
            )
        }
    }

    private func handleStampRotate(placementID: UUID, degrees: Double) {
        updatePlacement(placementID) { current in
            current.rotationDegrees = degrees
        }
    }

    private func finishStampTransform() {
        transformAnchorNormalized = nil
        draggingPlacementID = nil
        resizingPlacementID = nil
    }

    private func handleSignTap(at location: CGPoint, fitSize: CGSize) {
        guard canMarkUpCurrentPage, editorMode == .sign, captureRole == nil else { return }
        guard location.x >= 0, location.y >= 0,
              location.x <= fitSize.width, location.y <= fitSize.height else { return }

        if let hitID = hitTestPlacementID(at: location, fitSize: fitSize) {
            selectedPlacementID = hitID
            return
        }

        selectedPlacementID = nil
        finishStampTransform()
        pendingStampCenter = CGPoint(
            x: location.x / fitSize.width,
            y: location.y / fitSize.height
        )
        captureRole = activeRole
        captureDrawing = PKDrawing()
    }

    private func hitTestPlacementID(at location: CGPoint, fitSize: CGSize) -> UUID? {
        let fitRect = CGRect(origin: .zero, size: fitSize)
        for placement in annotation.signaturePlacements.reversed() {
            let rect = placement.normalizedRect.viewRect(in: fitRect)
            if rect.contains(location) {
                return placement.id
            }
        }
        return nil
    }

    private func loadPage() {
        pageSize = AgreementDocumentStore.pageDocumentSize(
            path: sourcePath,
            pageIndex: pageIndex,
            kind: sourceKind
        ) ?? .zero

        pageImage = basePageImage(pageIndex: pageIndex)
        annotation = AgreementImportedPageAnnotationStore.loadOrDefault(
            agreementId: draft.id,
            pageIndex: pageIndex,
            pageSize: pageSize
        )

        if canMarkUpCurrentPage {
            drawing = AgreementImportedMarkupStore.loadDrawing(for: draft.id, pageIndex: pageIndex)
        } else {
            drawing = PKDrawing()
        }
        selectedPlacementID = nil
        captureRole = nil
        resetViewport()
    }

    private func basePageImage(pageIndex: Int) -> UIImage? {
        switch sourceKind {
        case .pdf:
            return AgreementDocumentStore.renderPageImage(path: sourcePath, pageIndex: pageIndex, scale: 2)
        case .image:
            return pageIndex == 0 ? AgreementDocumentStore.loadPreviewImage(path: sourcePath) : nil
        }
    }

    private func saveCurrentPage() {
        savePage(at: pageIndex)
    }

    private func savePage(at index: Int) {
        guard index >= 0, index < pageCount else { return }
        let size = AgreementDocumentStore.pageDocumentSize(
            path: sourcePath,
            pageIndex: index,
            kind: sourceKind
        ) ?? pageSize

        if AgreementImportedDocumentLimits.canMarkUp(pageIndex: index, pageCount: pageCount) {
            AgreementImportedMarkupStore.saveDrawing(drawing, for: draft.id, pageIndex: index)
            let canvasSize = markupCanvasSize(for: size)
            let saved = AgreementImportedPageAnnotation(
                pageSize: size,
                markupCanvasSize: canvasSize,
                signaturePlacements: annotation.signaturePlacements
            )
            AgreementImportedPageAnnotationStore.save(saved, agreementId: draft.id, pageIndex: index)
        }
    }

    private func applyCapturedSignature(_ png: Data, role: AgreementSignatureRole) {
        switch role {
        case .provider:
            draft.providerSignaturePNG = png
            draft.providerSignedAt = Date()
        case .client:
            draft.clientSignaturePNG = png
            draft.clientSignedAt = Date()
        }
        draft.refreshAgreementStatus()

        let center = pendingStampCenter ?? CGPoint(x: 0.5, y: 0.75)
        addPlacement(for: role, at: center)
        pendingStampCenter = nil
    }

    private func addPlacement(for role: AgreementSignatureRole, at center: CGPoint) {
        let aspect = pageSize.width / max(pageSize.height, 1)
        let normalized = AgreementImportedNormalizedRect.stamp(
            centeredAt: center,
            pageAspect: aspect,
            widthFraction: 0.34,
            heightFraction: 0.11
        )
        let placement = AgreementImportedSignaturePlacement(
            id: UUID(),
            role: role.storageKey,
            normalizedRect: normalized
        )
        annotation.signaturePlacements.removeAll { $0.role == role.storageKey }
        annotation.signaturePlacements.append(placement)
        selectedPlacementID = placement.id
    }

    private func updatePlacement(
        _ id: UUID,
        mutate: (inout AgreementImportedSignaturePlacement) -> Void
    ) {
        guard let index = annotation.signaturePlacements.firstIndex(where: { $0.id == id }) else { return }
        mutate(&annotation.signaturePlacements[index])
    }

    private func signatureImage(for role: AgreementSignatureRole) -> UIImage? {
        let data: Data?
        switch role {
        case .provider: data = draft.providerSignaturePNG
        case .client: data = draft.clientSignaturePNG
        }
        guard let data else { return nil }
        return AgreementImportedSignatureRasterizer.image(from: data)
    }

    private func scheduleLayoutContainerSize(_ size: CGSize) {
        DispatchQueue.main.async {
            layoutContainerSize = size
        }
    }

    private func markupCanvasSize(for pageDocumentSize: CGSize) -> CGSize {
        guard layoutContainerSize.width > 0, layoutContainerSize.height > 0 else {
            return pageDocumentSize
        }
        return AgreementImportedPageGeometry.aspectFitRect(
            contentSize: pageDocumentSize,
            in: layoutContainerSize
        ).size
    }
}
