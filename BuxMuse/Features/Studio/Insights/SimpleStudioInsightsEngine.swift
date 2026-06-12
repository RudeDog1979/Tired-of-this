//
//  SimpleStudioInsightsEngine.swift
//  BuxMuse
//

import Foundation

public struct SimpleStudioInsightsSnapshot: Equatable, Sendable {
    public var headline: String
    public var profitPerJobFormatted: String?
    public var openJobCount: Int
    public var waitingTotalFormatted: String?
    public var paidJobCount: Int
    public var rateTip: String?

    public static func empty(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> SimpleStudioInsightsSnapshot {
        SimpleStudioInsightsSnapshot(
            headline: SimpleStudioCopy.line("Log jobs to see earnings insights.", locale: locale),
            profitPerJobFormatted: nil,
            openJobCount: 0,
            waitingTotalFormatted: nil,
            paidJobCount: 0,
            rateTip: nil
        )
    }
}

public enum SimpleStudioInsightsEngine {

    public static func build(
        entries: [SimpleStudioEntry],
        currencyFormat: (Decimal) -> String,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> SimpleStudioInsightsSnapshot {
        let jobs = entries.filter { $0.kind == .job }
        guard !jobs.isEmpty else {
            return .empty(locale: locale)
        }

        let paidJobs = jobs.filter { $0.paymentStatus == .paid || $0.isJobFullyPaid }
        let openJobs = jobs.filter { !$0.isJobFullyPaid }

        let totalKept = jobs.reduce(Decimal(0)) { $0 + $1.keptSoFar }
        let profitPerJob = jobs.isEmpty ? Decimal(0) : totalKept / Decimal(jobs.count)

        let waitingTotal = openJobs.reduce(Decimal(0)) { $0 + $1.jobBalanceDue }

        var rateTip: String?
        let hourlyJobs = jobs.filter { $0.resolvedPayStyle == .byTheHour }
        if let underpriced = hourlyJobs.first(where: { job in
            guard let rate = job.hourlyRate, rate > 0, let logged = job.loggedSeconds, logged > 3600 else { return false }
            let earned = SimpleStudioTimePayEngine.earnings(seconds: logged, hourlyRate: rate)
            return earned < rate * 2
        }) {
            rateTip = SimpleStudioCopy.format(
                "Check rate on \"%@\" — logged time may be underpriced.",
                locale: locale,
                underpriced.jobLabel ?? underpriced.customerName
            )
        } else if openJobs.count >= 3 {
            rateTip = SimpleStudioCopy.format(
                "%lld jobs still waiting for payment — send a reminder from Waiting.",
                locale: locale,
                Int64(openJobs.count)
            )
        }

        let headline: String = {
            if paidJobs.count == jobs.count {
                return SimpleStudioCopy.line("All tracked jobs are paid. Nice work.", locale: locale)
            }
            if waitingTotal > 0 {
                return SimpleStudioCopy.format(
                    "You have money waiting on %lld job(s).",
                    locale: locale,
                    Int64(openJobs.count)
                )
            }
            return SimpleStudioCopy.line("Track profit and waiting balances at a glance.", locale: locale)
        }()

        return SimpleStudioInsightsSnapshot(
            headline: headline,
            profitPerJobFormatted: currencyFormat(profitPerJob),
            openJobCount: openJobs.count,
            waitingTotalFormatted: waitingTotal > 0 ? currencyFormat(waitingTotal) : nil,
            paidJobCount: paidJobs.count,
            rateTip: rateTip
        )
    }
}
