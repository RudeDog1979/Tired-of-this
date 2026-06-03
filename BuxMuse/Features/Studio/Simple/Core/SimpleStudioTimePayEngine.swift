//
//  SimpleStudioTimePayEngine.swift
//  BuxMuse
//
//  Plain-language pay math for Simple Studio work clock (one price vs by the hour).
//

import Foundation

/// How the customer pays for this job — drives work clock behavior.
public enum SimpleJobPayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// e.g. “$1,000 for the whole job” — clock time does not change what you're owed.
    case onePrice
    /// e.g. “$100 per hour” — clock time × rate = what they owe.
    case byTheHour

    public var id: String { rawValue }

    public var chipTitle: String {
        switch self {
        case .onePrice: return "One price"
        case .byTheHour: return "By the hour"
        }
    }

    public var plainTitle: String {
        switch self {
        case .onePrice: return "One price for the whole job"
        case .byTheHour: return "Paid by the hour"
        }
    }

    public var clockSubtitle: String {
        switch self {
        case .onePrice:
            return "Track your time — it does not change what you agreed."
        case .byTheHour:
            return "The clock figures out what they owe from your hourly rate."
        }
    }
}

enum SimpleStudioTimePayEngine {

    struct WorkClockSnapshot: Equatable {
        let style: SimpleJobPayStyle
        let loggedSeconds: TimeInterval
        let sessionSeconds: TimeInterval
        let totalSeconds: TimeInterval
        /// Main number to show (what the job is worth / owed from work).
        let customerOwesFromWork: Decimal
        let earningsThisSession: Decimal
        let paidSoFar: Decimal
        let stillWaiting: Decimal
        let hourlyRate: Decimal?
        let fixedAgreed: Decimal?
        let headline: String
        let detail: String
        let saveButtonHint: String
    }

    static func resolvedPayStyle(for job: SimpleStudioEntry) -> SimpleJobPayStyle {
        if let payStyle = job.payStyle { return payStyle }
        if let rate = job.hourlyRate, rate > 0 { return .byTheHour }
        return .onePrice
    }

    static func earnings(seconds: TimeInterval, hourlyRate: Decimal) -> Decimal {
        guard seconds > 0, hourlyRate > 0 else { return 0 }
        let hours = Decimal(seconds) / Decimal(3600)
        return hours * hourlyRate
    }

    static func workClockSnapshot(
        for job: SimpleStudioEntry,
        sessionSeconds: TimeInterval,
        formatMoney: (Decimal) -> String
    ) -> WorkClockSnapshot {
        let style = resolvedPayStyle(for: job)
        let logged = job.loggedSeconds ?? 0
        let total = logged + max(0, sessionSeconds)
        let paid = job.paidSoFar

        switch style {
        case .onePrice:
            let agreed = job.agreedPrice ?? job.amount
            let sessionLabel = StudioTimerSession.formattedDuration(sessionSeconds)
            let headline = formatMoney(agreed)
            let detail: String
            if sessionSeconds > 0 {
                detail = "You agreed \(formatMoney(agreed)) for this job. Even if you only work \(sessionLabel), they still owe the full agreed price."
            } else if logged > 0 {
                detail = "You agreed \(formatMoney(agreed)). Time logged is for your records — it does not reduce or increase the price."
            } else {
                detail = "You agreed \(formatMoney(agreed)) for the whole job. Use the clock to remember how long you spent."
            }
            return WorkClockSnapshot(
                style: style,
                loggedSeconds: logged,
                sessionSeconds: sessionSeconds,
                totalSeconds: total,
                customerOwesFromWork: agreed,
                earningsThisSession: 0,
                paidSoFar: paid,
                stillWaiting: max(0, agreed - paid),
                hourlyRate: nil,
                fixedAgreed: agreed,
                headline: headline,
                detail: detail,
                saveButtonHint: "Save time on this job (price stays \(formatMoney(agreed)))"
            )

        case .byTheHour:
            let rate = job.hourlyRate ?? 0
            let totalEarned = earnings(seconds: total, hourlyRate: rate)
            let sessionEarned = earnings(seconds: sessionSeconds, hourlyRate: rate)
            let hoursLabel = formattedHours(total)
            let headline = formatMoney(totalEarned)
            var detail = "At \(formatMoney(rate)) per hour, \(hoursLabel) of work = \(formatMoney(totalEarned))."
            if let cap = job.agreedPrice, cap > 0, totalEarned > cap {
                detail += " (Your ballpark quote was \(formatMoney(cap)) — check with the customer if hours ran over.)"
            } else if let cap = job.agreedPrice, cap > 0 {
                detail += " Ballpark quote was \(formatMoney(cap))."
            }
            if sessionSeconds > 0 {
                detail += " This session adds about \(formatMoney(sessionEarned))."
            }
            return WorkClockSnapshot(
                style: style,
                loggedSeconds: logged,
                sessionSeconds: sessionSeconds,
                totalSeconds: total,
                customerOwesFromWork: totalEarned,
                earningsThisSession: sessionEarned,
                paidSoFar: paid,
                stillWaiting: max(0, totalEarned - paid),
                hourlyRate: rate > 0 ? rate : nil,
                fixedAgreed: job.agreedPrice,
                headline: headline,
                detail: detail,
                saveButtonHint: sessionSeconds > 0
                    ? "Save \(StudioTimerSession.formattedDuration(sessionSeconds)) (~\(formatMoney(sessionEarned)))"
                    : "Save time to this job"
            )
        }
    }

    static func formattedHours(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0, mins > 0 { return "\(hours) h \(mins) m" }
        if hours > 0 { return "\(hours) h" }
        if mins > 0 { return "\(mins) m" }
        return "0 m"
    }
}

extension SimpleStudioEntry {
    public var resolvedPayStyle: SimpleJobPayStyle {
        SimpleStudioTimePayEngine.resolvedPayStyle(for: self)
    }

    public var loggedHoursLabel: String? {
        guard let loggedSeconds, loggedSeconds > 0 else { return nil }
        return SimpleStudioTimePayEngine.formattedHours(loggedSeconds)
    }
}
