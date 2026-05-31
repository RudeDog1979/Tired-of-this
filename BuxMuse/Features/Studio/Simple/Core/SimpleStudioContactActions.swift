//
//  SimpleStudioContactActions.swift
//  BuxMuse
//
//  Unified Send sheet — Share, WhatsApp, Message, Call (same everywhere).
//

import SwiftUI
import UIKit

enum SimpleStudioContactActions {

    struct Options {
        var sheetTitle: String = "Send"
        var message: String
        /// Who you're contacting (customer). When nil, WhatsApp opens contact picker with prefilled text.
        var recipientPhone: String?
        var shareItems: [Any]

        init(
            sheetTitle: String = "Send",
            message: String,
            recipientPhone: String? = nil,
            shareItems: [Any]? = nil
        ) {
            self.sheetTitle = sheetTitle
            self.message = message
            self.recipientPhone = recipientPhone?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.shareItems = shareItems ?? [message]
        }
    }

    @MainActor
    static func present(_ options: Options, openURL: OpenURLAction) {
        let phone = options.recipientPhone.flatMap { $0.isEmpty ? nil : $0 }
        let sheet = UIAlertController(title: options.sheetTitle, message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Share…", style: .default) { _ in
            SimpleStudioShareHelper.present(items: options.shareItems)
        })

        let hasImage = options.shareItems.contains { $0 is UIImage }
        let hasContactFile = options.shareItems.contains { item in
            guard let url = item as? URL else { return false }
            return url.pathExtension.lowercased() == "vcf"
        }
        let prefersShareSheet = hasImage || hasContactFile

        if prefersShareSheet {
            sheet.addAction(UIAlertAction(title: "WhatsApp", style: .default) { _ in
                SimpleStudioShareHelper.present(items: options.shareItems)
            })
        } else if let whatsApp = whatsAppURL(phone: phone, message: options.message) {
            sheet.addAction(UIAlertAction(title: "WhatsApp", style: .default) { _ in
                openURL(whatsApp)
            })
        }

        if prefersShareSheet {
            sheet.addAction(UIAlertAction(title: "Message", style: .default) { _ in
                SimpleStudioShareHelper.present(items: options.shareItems)
            })
        } else if let phone, SimpleStudioContactHelper.smsURL(phone: phone, message: options.message) != nil {
            sheet.addAction(UIAlertAction(title: "Message", style: .default) { _ in
                if let url = SimpleStudioContactHelper.smsURL(phone: phone, message: options.message) {
                    openURL(url)
                }
            })
        }

        if let phone, SimpleStudioContactHelper.telURL(phone: phone) != nil {
            sheet.addAction(UIAlertAction(title: "Call", style: .default) { _ in
                if let url = SimpleStudioContactHelper.telURL(phone: phone) {
                    openURL(url)
                }
            })
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        guard let presenter = topViewController() else {
            SimpleStudioShareHelper.present(items: options.shareItems)
            return
        }
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(sheet, animated: true)
    }

    /// WhatsApp to a specific person, or open WhatsApp to pick a contact when phone is nil.
    static func whatsAppURL(phone: String?, message: String) -> URL? {
        if let phone, !phone.isEmpty,
           let direct = SimpleStudioContactHelper.whatsAppURL(phone: phone, message: message) {
            return direct
        }
        var components = URLComponents(string: "https://wa.me/")
        components?.queryItems = [URLQueryItem(name: "text", value: message)]
        return components?.url
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
