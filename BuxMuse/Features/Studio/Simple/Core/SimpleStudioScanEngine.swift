//
//  SimpleStudioScanEngine.swift
//  BuxMuse
//
//  Offline Vision OCR + heuristics for payment screenshots and receipts.
//

import Foundation
import UIKit
import Vision

enum SimpleStudioScanEngine {

    static func parseImage(
        _ image: UIImage,
        persona: StudioPersona,
        completion: @escaping (Result<SimpleScanDraft, Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ScanError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                completion(.failure(error))
                return
            }
            let lines = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            let draft = parseLines(lines, persona: persona)
            completion(.success(draft))
        }
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func parseLines(_ lines: [String], persona: StudioPersona) -> SimpleScanDraft {
        let joined = lines.joined(separator: " ").lowercased()
        var draft = SimpleScanDraft()
        draft.kind = inferKind(from: joined, persona: persona)
        draft.amount = inferAmount(from: lines)
        draft.customerName = inferCustomer(from: lines, kind: draft.kind)
        draft.jobLabel = inferJobLabel(from: lines, customer: draft.customerName)
        draft.date = inferDate(from: lines) ?? Date()
        draft.note = inferNote(from: lines)
        draft.paymentStatus = inferPaymentStatus(kind: draft.kind, text: joined)
        return draft
    }

    static func simulatorDraft(persona: StudioPersona) -> SimpleScanDraft {
        switch persona {
        case .jobsAndRepairs:
            return SimpleScanDraft(
                kind: .income,
                amount: 500,
                customerName: "Marcus",
                jobLabel: "Bathroom tiles",
                note: "Wire transfer screenshot",
                paymentStatus: .paid
            )
        case .tasksAndGigs:
            return SimpleScanDraft(
                kind: .job,
                amount: 85,
                customerName: "Sarah",
                jobLabel: "Furniture assembly",
                note: "Task payment",
                paymentStatus: .paid
            )
        case .driving:
            return SimpleScanDraft(
                kind: .expense,
                amount: 45,
                customerName: "Shell",
                jobLabel: "Petrol",
                note: "Fuel receipt",
                paymentStatus: .paid
            )
        case .lending:
            return SimpleScanDraft(
                kind: .repaymentReceived,
                amount: 200,
                customerName: "Keisha",
                jobLabel: "Loan repayment",
                paymentStatus: .paid
            )
        default:
            return SimpleScanDraft(
                kind: .income,
                amount: 150,
                customerName: "Customer",
                jobLabel: "Work payment",
                paymentStatus: .paid
            )
        }
    }

    // MARK: - Heuristics

    private static func inferKind(from text: String, persona: StudioPersona) -> SimpleEntryKind {
        if text.contains("advance") || text.contains("materials deposit") {
            return .advanceReceived
        }
        if text.contains("they owe") || text.contains("amount due") || text.contains("invoice") {
            return .owedToMe
        }
        if text.contains("repayment") || text.contains("paid back") || text.contains("loan payment") {
            return .repaymentReceived
        }
        if text.contains("i lent") || text.contains("loaned") {
            return .lent
        }
        if text.contains("i owe") || text.contains("you owe") {
            return .iOwe
        }

        let expenseHints = [
            "purchase", "debited", "spent", "payment to", "paid to", "sent to",
            "withdrawal", "hardware", "materials", "receipt", "fuel", "petrol", "gas station"
        ]
        let incomeHints = [
            "received", "payment from", "credited", "deposited", "you got", "sent you",
            "transfer from", "paid you", "incoming", "zelle", "venmo", "cash app", "paypal"
        ]

        let expenseScore = expenseHints.filter { text.contains($0) }.count
        let incomeScore = incomeHints.filter { text.contains($0) }.count

        if expenseScore > incomeScore {
            if persona == .driving && (text.contains("fuel") || text.contains("petrol") || text.contains("gas")) {
                return .expense
            }
            if text.contains("material") || text.contains("cement") || text.contains("hardware") {
                return .expense
            }
            return .expense
        }
        if incomeScore > 0 {
            if persona == .jobsAndRepairs || persona == .tasksAndGigs {
                return .job
            }
            return .income
        }

        switch persona {
        case .jobsAndRepairs, .tasksAndGigs: return .job
        case .lending: return .repaymentReceived
        case .shop: return .income
        default: return .income
        }
    }

    private static func inferAmount(from lines: [String]) -> Decimal {
        let pattern = #"(?:\$|€|£|J\$|TT\$|EC\$|BZ\$|GY\$|HTG|USD|JMD|TTD|XCD)?\s*(\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2})|\d+[.,]\d{2})"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        var candidates: [Decimal] = []

        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            regex?.enumerateMatches(in: line, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let valueRange = Range(match.range(at: 1), in: line) else { return }
                let raw = line[valueRange]
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: "")
                if let decimal = Decimal(string: String(raw)) {
                    candidates.append(decimal)
                }
            }
        }

        if let labeled = labeledAmount(from: lines) { return labeled }
        return candidates.max() ?? 0
    }

    private static func labeledAmount(from lines: [String]) -> Decimal? {
        let labels = ["total", "amount", "paid", "received", "balance", "payment"]
        let pattern = #"\b\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2})|\d+[.,]\d{2}\b"#
        let regex = try? NSRegularExpression(pattern: pattern)

        for line in lines {
            let lower = line.lowercased()
            guard labels.contains(where: { lower.contains($0) }) else { continue }
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = regex?.firstMatch(in: line, options: [], range: range),
               let valueRange = Range(match.range, in: line) {
                let raw = line[valueRange]
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: "")
                if let decimal = Decimal(string: String(raw)) {
                    return decimal
                }
            }
        }
        return nil
    }

    private static func inferCustomer(from lines: [String], kind: SimpleEntryKind) -> String {
        let patterns = [
            #"(?i)(?:from|to|paid (?:to|by)|sent (?:to|by)|received from|payment from)\s+([A-Za-z][A-Za-z\s'.-]{1,40})"#,
            #"(?i)(?:customer|client|name)\s*[:\-]\s*([A-Za-z][A-Za-z\s'.-]{1,40})"#
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: line) else { continue }
                let name = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if name.count >= 2, !isNoiseName(name) {
                    return name.capitalized
                }
            }
        }

        if kind == .expense, let merchant = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 2, trimmed.count <= 40, !trimmed.contains(where: { $0.isNumber }) {
                return trimmed
            }
        }

        return ""
    }

    private static func inferJobLabel(from lines: [String], customer: String) -> String {
        let keywords = ["job", "work", "service", "task", "project", "repair", "clean", "delivery", "invoice for"]
        for line in lines {
            let lower = line.lowercased()
            for keyword in keywords where lower.contains(keyword) {
                if let colon = line.firstIndex(of: ":") {
                    let after = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !after.isEmpty { return after }
                }
                let cleaned = line
                    .replacingOccurrences(of: customer, with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count >= 3 { return cleaned }
            }
        }
        return ""
    }

    private static func inferDate(from lines: [String]) -> Date? {
        let pattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let formats = ["MM/dd/yyyy", "dd/MM/yyyy", "MM-dd-yyyy", "dd-MM-yyyy", "MM/dd/yy", "dd/MM/yy"]

        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            guard let match = regex?.firstMatch(in: line, options: [], range: range),
                  let matchRange = Range(match.range, in: line) else { continue }
            let token = String(line[matchRange])
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: token) { return date }
            }
        }
        return nil
    }

    private static func inferNote(from lines: [String]) -> String {
        let noteKeywords = ["memo", "note", "description", "for"]
        for line in lines {
            let lower = line.lowercased()
            for keyword in noteKeywords where lower.hasPrefix(keyword) {
                if let colon = line.firstIndex(of: ":") {
                    return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return lines.prefix(3).joined(separator: " · ")
    }

    private static func inferPaymentStatus(kind: SimpleEntryKind, text: String) -> SimplePaymentStatus {
        switch kind {
        case .owedToMe, .job:
            if text.contains("paid in full") || text.contains("payment received") {
                return .paid
            }
            if text.contains("partial") || text.contains("deposit") {
                return .partial
            }
            return kind == .owedToMe ? .unpaid : .paid
        default:
            return .paid
        }
    }

    private static func isNoiseName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let noise = ["usd", "total", "amount", "payment", "transfer", "receipt", "balance", "date"]
        return noise.contains(where: { lower.contains($0) })
    }

    enum ScanError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            let locale = BuxInterfaceLocale.currentInterfaceLocale
            switch self {
            case .invalidImage:
                return BuxLocalizedString.string("Could not read that photo.", locale: locale)
            }
        }
    }
}
