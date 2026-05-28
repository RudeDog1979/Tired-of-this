//
//  ImageCropView.swift
//  BuxMuse
//
//  Shared pan/zoom crop sheet for avatars, logos, and receipt imports.
//

import SwiftUI
import PhotosUI

// MARK: - Crop shape

public enum ImageCropShape {
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
}

// MARK: - Photo loading

public enum PhotoImageLoader {
    @MainActor
    public static func loadUIImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item else { return nil }

        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            return image
        }

        if let url = try? await item.loadTransferable(type: URL.self),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }
}

// MARK: - Crop sheet

public struct ImageCropView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let inputImage: UIImage
    let cropShape: ImageCropShape
    let title: String
    let hint: String
    let onCrop: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let viewportSize: CGFloat = 320
    private let cropSize: CGFloat = 260

    public init(
        inputImage: UIImage,
        cropShape: ImageCropShape = .circle,
        title: String = "Crop Photo",
        hint: String = "Drag to pan, slide to scale.",
        onCrop: @escaping (UIImage) -> Void
    ) {
        self.inputImage = inputImage
        self.cropShape = cropShape
        self.title = title
        self.hint = hint
        self.onCrop = onCrop
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(hint)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top, 16)

                ZStack {
                    cropContent
                    cropOverlay
                }
                .frame(width: viewportSize, height: viewportSize)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.gray)
                        Slider(value: $scale, in: 1.0...4.0)
                            .tint(themeManager.current.accentColor)
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)

                    Text("Scale: \(String(format: "%.1fx", scale))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        if let cropped = performCrop() {
                            onCrop(cropped)
                        }
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private var cropContent: some View {
        Image(uiImage: inputImage)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .frame(width: viewportSize, height: viewportSize)
            .clipped()
    }

    @ViewBuilder
    private var cropOverlay: some View {
        switch cropShape {
        case .circle:
            CircleCutoutOverlay(circleRadius: cropSize / 2)
                .allowsHitTesting(false)
        case .roundedRectangle(let radius):
            RoundedRectCutoutOverlay(cornerRadius: radius, size: cropSize)
                .allowsHitTesting(false)
        }
    }

    @MainActor
    private func performCrop() -> UIImage? {
        let normalized = inputImage.normalizedImage()

        let cropView = ZStack {
            Image(uiImage: normalized)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: viewportSize, height: viewportSize)
        }
        .frame(width: cropSize, height: cropSize)
        .clipped()

        let renderer = ImageRenderer(content: cropView)
        renderer.scale = 3.0
        guard let image = renderer.uiImage else { return nil }

        switch cropShape {
        case .circle:
            return image.circularMasked()
        case .roundedRectangle(let radius):
            return image.roundedRectMasked(cornerRadius: radius * 3.0)
        }
    }
}

// MARK: - Logo / avatar picker row

public struct PhotoPickCropRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let subtitle: String
    let imageData: Data?
    let cropShape: ImageCropShape
    let cropTitle: String
    let previewSize: CGFloat
    let previewCornerRadius: CGFloat
    let onImageCropped: (Data) -> Void

    @State private var pickedImage: UIImage?
    @State private var showCropSheet = false
    @State private var showNativePicker = false
    @State private var loadFailed = false

    public init(
        title: String,
        subtitle: String,
        imageData: Data?,
        cropShape: ImageCropShape,
        cropTitle: String = "Crop Photo",
        previewSize: CGFloat = 64,
        previewCornerRadius: CGFloat = 12,
        onImageCropped: @escaping (Data) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageData = imageData
        self.cropShape = cropShape
        self.cropTitle = cropTitle
        self.previewSize = previewSize
        self.previewCornerRadius = previewCornerRadius
        self.onImageCropped = onImageCropped
    }

    public var body: some View {
        HStack(spacing: BuxLayout.section) {
            Button(action: { showNativePicker = true }) {
                preview
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                if loadFailed {
                    Text("Couldn't load that photo — try another image.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: showNativePicker) { _, show in
            if show {
                GlobalImagePickerCoordinator.shared.present { image in
                    if let image = image {
                        loadFailed = false
                        pickedImage = image
                        showCropSheet = true
                    } else {
                        loadFailed = true
                    }
                    showNativePicker = false
                }
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let pickedImage {
                ImageCropView(
                    inputImage: pickedImage,
                    cropShape: cropShape,
                    title: cropTitle,
                    onCrop: { cropped in
                        if let data = cropped.jpegData(compressionQuality: 0.85) {
                            onImageCropped(data)
                        }
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let data = imageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: previewSize, height: previewSize)
                .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: previewCornerRadius)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .fill(themeManager.current.accentColor.opacity(0.12))
                    .frame(width: previewSize, height: previewSize)
                Image(systemName: "camera.fill")
                    .font(.system(size: previewSize * 0.32))
                    .foregroundColor(themeManager.current.accentColor)
            }
        }
    }
}

// MARK: - Overlays & image helpers

struct CircleCutoutOverlay: View {
    let circleRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addEllipse(in: CGRect(
                    x: size.width / 2 - circleRadius,
                    y: size.height / 2 - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))

            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: circleRadius * 2, height: circleRadius * 2)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }
}

struct RoundedRectCutoutOverlay: View {
    let cornerRadius: CGFloat
    let size: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(
                x: (geometry.size.width - size) / 2,
                y: (geometry.size.height - size) / 2,
                width: size,
                height: size
            )
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    func circularMasked() -> UIImage {
        let side = min(size.width, size.height)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).addClip()
            draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
    }

    func roundedRectMasked(cornerRadius: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            draw(in: rect)
        }
    }
}

// MARK: - Native Image Picker (Global Presenter)
public class GlobalImagePickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    public static let shared = GlobalImagePickerCoordinator()
    
    private var onImagePicked: ((UIImage?) -> Void)?
    
    public func present(onPicked: @escaping (UIImage?) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        self.onImagePicked = onPicked
        
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        
        // Present globally to avoid SwiftUI nested .sheet blank view bugs
        rootVC.present(picker, animated: true)
    }
    
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            DispatchQueue.main.async {
                self.onImagePicked?(nil)
            }
            return
        }
        
        provider.loadObject(ofClass: UIImage.self) { image, _ in
            DispatchQueue.main.async {
                self.onImagePicked?(image as? UIImage)
            }
        }
    }
}
