//
//  SimpleStudioReminderHelper.swift
//  BuxMuse
//

import SwiftUI

enum SimpleStudioReminderHelper {

    struct Payload {
        var customerName: String
        var amountFormatted: String
        var jobLabel: String
        var businessName: String
        var phone: String?
        var accent: Color
    }

    @MainActor
    static func presentContactOptions(_ payload: Payload, openURL: OpenURLAction) {
        let trimmedName = payload.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = trimmedName.isEmpty ? "Hi" : "Hi \(trimmedName)"
        let message = "\(greeting) — friendly reminder: balance of \(payload.amountFormatted) for \(payload.jobLabel). Thanks!"

        var items: [Any] = [message]
        let card = SimpleInvoiceCardView(
            businessName: payload.businessName,
            customerName: trimmedName.isEmpty ? "Customer" : trimmedName,
            amountFormatted: payload.amountFormatted,
            description: payload.jobLabel,
            isPaid: false,
            accent: payload.accent
        )
        if let image = SimpleStudioShareHelper.renderCard(card) {
            items.append(image)
        }

        SimpleStudioContactActions.present(
            SimpleStudioContactActions.Options(
                sheetTitle: "Send reminder",
                message: message,
                recipientPhone: payload.phone,
                shareItems: items
            ),
            openURL: openURL
        )
    }
}
