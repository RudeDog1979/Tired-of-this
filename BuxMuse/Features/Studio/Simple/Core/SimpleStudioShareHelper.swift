//
//  SimpleStudioShareHelper.swift
//  BuxMuse
//
//  Native iOS share sheet — user picks WhatsApp, Messages, Mail, etc.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BuxPDFSharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]

    init(data: Data, fileName: String) {
        activityItems = [BuxPDFActivityItem(data: data, fileName: fileName)]
    }
}

struct BuxActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                onComplete?()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Supplies PDF data to UIActivityViewController with an explicit UTType.
private final class BuxPDFActivityItem: NSObject, UIActivityItemSource {
    private let data: Data
    private let fileName: String
    private var cachedURL: URL?

    init(data: Data, fileName: String) {
        self.data = data
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Document" : trimmed.replacingOccurrences(of: "/", with: "-")
        self.fileName = base.hasSuffix(".pdf") ? String(base.dropLast(4)) : base
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        data
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if let cachedURL { return cachedURL }
        do {
            let url = try Self.writePDF(data: data, fileName: fileName)
            cachedURL = url
            return url
        } catch {
            return data
        }
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.pdf.identifier
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        fileName
    }

    private static func writePDF(data: Data, fileName: String) throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ShareExports", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent("\(fileName).pdf")
        try data.write(to: url, options: [.atomic])
        try (url as NSURL).setResourceValue(UTType.pdf.identifier, forKey: .typeIdentifierKey)
        return url
    }
}

enum SimpleStudioShareHelper {

    @MainActor
    static func makePDFSharePayload(data: Data, fileName: String) -> BuxPDFSharePayload {
        BuxPDFSharePayload(data: data, fileName: fileName)
    }

    /// Presents the system share sheet directly — avoids double-sheet LaunchServices glitches.
    @MainActor
    static func presentPDF(data: Data, fileName: String, excludedTypes: [UIActivity.ActivityType] = []) {
        present(items: [BuxPDFActivityItem(data: data, fileName: fileName)], excludedTypes: excludedTypes)
    }

    @MainActor
    static func present(items: [Any], excludedTypes: [UIActivity.ActivityType] = []) {
        // Defer past the tap gesture so the system gesture gate can finish.
        DispatchQueue.main.async {
            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.excludedActivityTypes = excludedTypes
            configurePresentationStyle(for: controller)

            guard let presenter = topViewController() else { return }
            if let popover = controller.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            presenter.present(controller, animated: true)
        }
    }

    @MainActor
    static func renderCard<V: View>(_ content: V, width: CGFloat = 340) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: width))
        renderer.scale = max(UIScreen.main.scale, 2)
        if #available(iOS 18.0, *) {
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        }
        return renderer.uiImage
    }

    private static func configurePresentationStyle(for controller: UIActivityViewController) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.modalPresentationStyle = .popover
            return
        }
        if #available(iOS 26, *) {
            controller.modalPresentationStyle = .pageSheet
        } else {
            controller.modalPresentationStyle = .pageSheet
            controller.modalTransitionStyle = .coverVertical
        }
    }

    @MainActor
    private static func topViewController(from base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
            return scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController
        }()
        guard let root else { return nil }
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController ?? nav)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController ?? tab)
        }
        return root
    }
}
