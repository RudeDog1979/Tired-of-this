//
//  SimpleStudioShareHelper.swift
//  BuxMuse
//
//  Native iOS share sheet — user picks WhatsApp, Messages, Mail, etc.
//

import SwiftUI
import UIKit

enum SimpleStudioShareHelper {

    @MainActor
    static func present(items: [Any], excludedTypes: [UIActivity.ActivityType] = []) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedTypes
        controller.popoverPresentationController?.sourceView = topViewController()?.view

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

    @MainActor
    static func renderCard<V: View>(_ content: V, width: CGFloat = 340) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: width))
        renderer.scale = max(UIScreen.main.scale, 2)
        if #available(iOS 18.0, *) {
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        }
        return renderer.uiImage
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              var controller = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene.windows.first?.rootViewController else { return nil }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}
