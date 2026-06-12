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

    public func localizedChipTitle(locale: Locale) -> String {
        switch self {
        case .onePrice: return SimpleStudioCopy.line("One price", locale: locale)
        case .byTheHour: return SimpleStudioCopy.line("By the hour", locale: locale)
        }
    }

    public var chipTitle: String {
        localizedChipTitle(locale: BuxInterfaceLocale.currentInterfaceLocale)
    }

    public func localizedPlainTitle(locale: Locale) -> String {
        switch self {
        case .onePrice: return SimpleStudioCopy.line("One price for the whole job", locale: locale)
        case .byTheHour: return SimpleStudioCopy.line("Paid by the hour", locale: locale)
        }
    }

    public var plainTitle: String {
        localizedPlainTitle(locale: BuxInterfaceLocale.currentInterfaceLocale)
    }

    public func localizedClockSubtitle(locale: Locale) -> String {
        switch self {
        case .onePrice:
            return SimpleStudioCopy.line("Track your time — it does not change what you agreed.", locale: locale)
        case .byTheHour:
            return SimpleStudioCopy.line("The clock figures out what they owe from your hourly rate.", locale: locale)
        }
    }

    public var clockSubtitle: String {
        localizedClockSubtitle(locale: BuxInterfaceLocale.currentInterfaceLocale)
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

        let locale = BuxInterfaceLocale.currentInterfaceLocale

        switch style {
        case .onePrice:
            let agreed = job.agreedPrice ?? job.amount
            let sessionLabel = StudioTimerSession.formattedDuration(sessionSeconds)
            let headline = formatMoney(agreed)
            let detail: String
            if sessionSeconds > 0 {
                detail = String(
                    format: SimpleStudioCopy.line("You agreed %@ for this job. Even if you only work %@, they still owe the full agreed price.", locale: locale),
                    locale: locale,
                    formatMoney(agreed),
                    sessionLabel
                )
            } else if logged > 0 {
                detail = String(
                    format: SimpleStudioCopy.line("You agreed %@. Time logged is for your records — it does not reduce or increase the price.", locale: locale),
                    locale: locale,
                    formatMoney(agreed)
                )
            } else {
                detail = String(
                    format: SimpleStudioCopy.line("You agreed %@ for the whole job. Use the clock to remember how long you spent.", locale: locale),
                    locale: locale,
                    formatMoney(agreed)
                )
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
                saveButtonHint: String(
                    format: SimpleStudioCopy.line("Save time on this job (price stays %@)", locale: locale),
                    locale: locale,
                    formatMoney(agreed)
                )
            )

        case .byTheHour:
            let rate = job.hourlyRate ?? 0
            let totalEarned = earnings(seconds: total, hourlyRate: rate)
            let sessionEarned = earnings(seconds: sessionSeconds, hourlyRate: rate)
            let hoursLabel = formattedHours(total)
            let headline = formatMoney(totalEarned)
            var detail = String(
                format: SimpleStudioCopy.line("At %@ per hour, %@ of work = %@.", locale: locale),
                locale: locale,
                formatMoney(rate),
                hoursLabel,
                formatMoney(totalEarned)
            )
            if let cap = job.agreedPrice, cap > 0, totalEarned > cap {
                detail += " " + String(
                    format: SimpleStudioCopy.line("(Your ballpark quote was %@ — check with the customer if hours ran over.)", locale: locale),
                    locale: locale,
                    formatMoney(cap)
                )
            } else if let cap = job.agreedPrice, cap > 0 {
                detail += " " + String(
                    format: SimpleStudioCopy.line("Ballpark quote was %@.", locale: locale),
                    locale: locale,
                    formatMoney(cap)
                )
            }
            if sessionSeconds > 0 {
                detail += " " + String(
                    format: SimpleStudioCopy.line("This session adds about %@.", locale: locale),
                    locale: locale,
                    formatMoney(sessionEarned)
                )
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
                    ? String(
                        format: SimpleStudioCopy.line("Save %@ (~%@)", locale: locale),
                        locale: locale,
                        StudioTimerSession.formattedDuration(sessionSeconds),
                        formatMoney(sessionEarned)
                    )
                    : SimpleStudioCopy.line("Save time to this job", locale: locale)
            )
        }
    }

    static func formattedHours(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        if hours > 0, mins > 0 {
            return String(
                format: SimpleStudioCopy.line("%ld h %ld m", locale: locale),
                locale: locale,
                hours,
                mins
            )
        }
        if hours > 0 {
            return String(
                format: SimpleStudioCopy.line("%ld h", locale: locale),
                locale: locale,
                hours
            )
        }
        if mins > 0 {
            return String(
                format: SimpleStudioCopy.line("%ld m", locale: locale),
                locale: locale,
                mins
            )
        }
        return SimpleStudioCopy.line("0 m", locale: locale)
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
