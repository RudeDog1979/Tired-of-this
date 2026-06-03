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
    /// Width ÷ height of the visible crop window (e.g. business card 3.5÷2).
    case aspectFill(ratio: CGFloat, cornerRadius: CGFloat = 0)
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

    private let viewportSize: CGFloat = 320
    private let cropSize: CGFloat = 260

    private var cropFrameSize: CGSize {
        switch cropShape {
        case .aspectFill(let ratio, _):
            guard ratio > 0 else { return CGSize(width: cropSize, height: cropSize) }
            if ratio >= 1 {
                return CGSize(width: cropSize, height: cropSize / ratio)
            }
            return CGSize(width: cropSize * ratio, height: cropSize)
        default:
            return CGSize(width: cropSize, height: cropSize)
        }
    }

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

                ImageCropEditorContent(
                    inputImage: inputImage,
                    cropShape: cropShape,
                    scale: $scale,
                    offset: $offset
                )

                Spacer()
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Apply") {
                        if let cropped = ImageCropRenderer.croppedImage(
                            inputImage: inputImage,
                            cropShape: cropShape,
                            scale: scale,
                            offset: offset
                        ) {
                            onCrop(cropped)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Embeddable crop editor (no sheet — for Bux Canvas background)

public struct ImageCropEditorContent: View {
    @EnvironmentObject private var themeManager: ThemeManager

    public let inputImage: UIImage
    public let cropShape: ImageCropShape
    public var viewportSize: CGFloat = 320
    public var cropSize: CGFloat = 260
    @Binding public var scale: CGFloat
    @Binding public var offset: CGSize

    @State private var lastOffset: CGSize = .zero

    public init(
        inputImage: UIImage,
        cropShape: ImageCropShape,
        scale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        viewportSize: CGFloat = 320,
        cropSize: CGFloat = 260
    ) {
        self.inputImage = inputImage
        self.cropShape = cropShape
        self._scale = scale
        self._offset = offset
        self.viewportSize = viewportSize
        self.cropSize = cropSize
    }

    private var cropFrameSize: CGSize {
        switch cropShape {
        case .aspectFill(let ratio, _):
            guard ratio > 0 else { return CGSize(width: cropSize, height: cropSize) }
            if ratio >= 1 {
                return CGSize(width: cropSize, height: cropSize / ratio)
            }
            return CGSize(width: cropSize * ratio, height: cropSize)
        default:
            return CGSize(width: cropSize, height: cropSize)
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                cropContent
                cropOverlay
            }
            .frame(width: viewportSize, height: viewportSize)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            HStack {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundStyle(.secondary)
                Slider(value: $scale, in: 1...4)
                    .tint(themeManager.current.accentColor)
                Image(systemName: "plus.magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            Text("Scale: \(String(format: "%.1fx", scale))")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
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
        case .aspectFill(_, let radius):
            AspectRectCutoutOverlay(frameSize: cropFrameSize, cornerRadius: radius)
                .allowsHitTesting(false)
        }
    }
}

public enum ImageCropRenderer {
    private static let viewportSize: CGFloat = 320
    private static let cropSize: CGFloat = 260

    @MainActor
    public static func croppedImage(
        inputImage: UIImage,
        cropShape: ImageCropShape,
        scale: CGFloat,
        offset: CGSize,
        viewportSize: CGFloat = 320,
        cropSize: CGFloat = 260
    ) -> UIImage? {
        let frame = cropFrameSize(for: cropShape, cropSize: cropSize)
        return croppedImage(
            inputImage: inputImage,
            scale: scale,
            offset: offset,
            viewportSize: CGSize(width: viewportSize, height: viewportSize),
            cropFrameSize: frame,
            cornerRadius: cornerRadius(for: cropShape, cropFrameWidth: frame.width),
            exportSize: frame
        )
    }

    @MainActor
    public static func croppedImage(
        inputImage: UIImage,
        scale: CGFloat,
        offset: CGSize,
        viewportSize: CGSize,
        cropFrameSize: CGSize,
        cornerRadius: CGFloat,
        exportSize: CGSize,
        paperColorHex: String? = nil
    ) -> UIImage? {
        let normalized = inputImage.normalizedImage()

        let cropView = ZStack {
            Image(uiImage: normalized)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: viewportSize.width, height: viewportSize.height)
        }
        .frame(width: cropFrameSize.width, height: cropFrameSize.height)
        .clipped()

        let renderer = ImageRenderer(content: cropView)
        renderer.scale = 3.0
        guard var snippet = renderer.uiImage else { return nil }

        let maskRadius = cornerRadius * (snippet.size.width / max(1, cropFrameSize.width))
        snippet = snippet.roundedRectMasked(cornerRadius: maskRadius)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let paper = paperColorHex.map { UIColor(Color(hex: $0)) } ?? .white

        return UIGraphicsImageRenderer(size: exportSize, format: format).image { _ in
            paper.setFill()
            UIRectFill(CGRect(origin: .zero, size: exportSize))
            snippet.draw(in: CGRect(origin: .zero, size: exportSize))
        }
    }

    private static func cornerRadius(for cropShape: ImageCropShape, cropFrameWidth: CGFloat) -> CGFloat {
        switch cropShape {
        case .circle: return cropFrameWidth / 2
        case .roundedRectangle(let radius): return radius
        case .aspectFill(_, let radius): return radius
        }
    }

    private static func cropFrameSize(for cropShape: ImageCropShape, cropSize: CGFloat) -> CGSize {
        switch cropShape {
        case .aspectFill(let ratio, _):
            guard ratio > 0 else { return CGSize(width: cropSize, height: cropSize) }
            if ratio >= 1 {
                return CGSize(width: cropSize, height: cropSize / ratio)
            }
            return CGSize(width: cropSize * ratio, height: cropSize)
        default:
            return CGSize(width: cropSize, height: cropSize)
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

struct AspectRectCutoutOverlay: View {
    let frameSize: CGSize
    let cornerRadius: CGFloat

    @ViewBuilder
    private func strokeFrame(in geometry: GeometryProxy) -> some View {
        if cornerRadius > 0 {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: frameSize.width, height: frameSize.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        } else {
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: frameSize.width, height: frameSize.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(
                x: (geometry.size.width - frameSize.width) / 2,
                y: (geometry.size.height - frameSize.height) / 2,
                width: frameSize.width,
                height: frameSize.height
            )
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                if cornerRadius > 0 {
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
                } else {
                    path.addRect(rect)
                }
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))

            strokeFrame(in: geometry)
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
            onPicked(nil)
            return
        }

        self.onImagePicked = onPicked

        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self

        // Present from the topmost controller to avoid SwiftUI nested sheet blank bugs.
        topViewController(from: rootVC).present(picker, animated: true)
    }

    private func topViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return controller
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
