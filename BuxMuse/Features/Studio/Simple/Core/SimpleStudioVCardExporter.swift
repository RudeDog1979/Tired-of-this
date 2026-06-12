//
//  SimpleStudioVCardExporter.swift
//  BuxMuse
//
//  Builds a shareable .vcf contact file from a Simple Studio business card.
//

import Contacts
import UIKit

enum SimpleStudioVCardExporter {

    /// Writes a temporary `.vcf` the recipient can tap to save your contact.
    static func temporaryFileURL(for card: SimpleBusinessCard, photo: UIImage?) -> URL? {
        let name = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let contact = CNMutableContact()
        contact.givenName = name

        let tagline = card.tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tagline.isEmpty {
            contact.organizationName = tagline
        }

        let phone = card.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phone.isEmpty {
            contact.phoneNumbers = [
                CNLabeledValue(
                    label: CNLabelPhoneNumberMobile,
                    value: CNPhoneNumber(stringValue: phone)
                )
            ]
        }

        let email = card.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: email as NSString)
            ]
        }

        let skills = card.skills.trimmingCharacters(in: .whitespacesAndNewlines)
        if !skills.isEmpty {
            contact.note = skills
        }

        if let photo, let data = photo.jpegData(compressionQuality: 0.82) {
            contact.imageData = data
        }

        guard let data = try? CNContactVCardSerialization.data(with: [contact]) else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFilename(name)).vcf")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("SimpleStudioVCardExporter: write error \(error)")
            return nil
        }
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        let trimmed = String(cleaned.prefix(40))
        return trimmed.isEmpty ? "contact" : trimmed
    }
}
