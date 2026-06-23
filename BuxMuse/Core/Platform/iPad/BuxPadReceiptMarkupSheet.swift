//
//  BuxPadReceiptMarkupSheet.swift
//  BuxMuse — Apple Pencil markup over a receipt scan (iPad only).
//

import PencilKit
import SwiftUI

struct BuxPadReceiptMarkupSheet: View {
    enum Source {
        case savedReceipt(StudioReceipt)
        case draftImage(Binding<UIImage>)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let source: Source

    @State private var drawing = PKDrawing()
    @State private var baseImage: UIImage?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                if let baseImage {
                    GeometryReader { proxy in
                        ZStack {
                            Image(uiImage: baseImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            BuxPadPencilCanvasView(
                                drawing: $drawing,
                                drawingPolicy: .anyInput,
                                showsToolPicker: true,
                                inkColor: UIColor(themeManager.contrastAccentColor(for: colorScheme)),
                                inkWidth: 3.5
                            )
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(BuxLocalizedString.string("Receipt Markup", locale: BuxInterfaceLocale.currentInterfaceLocale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(BuxLocalizedString.string("Clear markup", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                        drawing = PKDrawing()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(BuxLocalizedString.string("Save", locale: BuxInterfaceLocale.currentInterfaceLocale)) {
                        saveMarkup()
                        BuxSaveFeedback.success()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .buxStudioSheetContent()
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        switch source {
        case .savedReceipt(let receipt):
            baseImage = BuxPadReceiptMarkupStore.loadReceiptImage(path: receipt.localImagePath)
            drawing = BuxPadReceiptMarkupStore.loadDrawing(for: receipt.id)
        case .draftImage(let binding):
            baseImage = binding.wrappedValue
            drawing = PKDrawing()
        }
    }

    private func saveMarkup() {
        switch source {
        case .savedReceipt(let receipt):
            BuxPadReceiptMarkupStore.saveDrawing(drawing, for: receipt.id)
        case .draftImage(let binding):
            guard let baseImage else { return }
            if let flattened = BuxPadPencilRasterizer.composite(base: baseImage, drawing: drawing) {
                binding.wrappedValue = flattened
            }
        }
    }
}
