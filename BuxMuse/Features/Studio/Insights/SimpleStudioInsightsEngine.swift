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

    public static let empty = SimpleStudioInsightsSnapshot(
        headline: "Log jobs to see earnings insights.",
        profitPerJobFormatted: nil,
        openJobCount: 0,
        waitingTotalFormatted: nil,
        paidJobCount: 0,
        rateTip: nil
    )
}

public enum SimpleStudioInsightsEngine {

    public static func build(
        entries: [SimpleStudioEntry],
        currencyFormat: (Decimal) -> String
    ) -> SimpleStudioInsightsSnapshot {
        let jobs = entries.filter { $0.kind == .job }
        guard !jobs.isEmpty else {
            return .empty
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
            rateTip = "Check rate on \"\(underpriced.jobLabel ?? underpriced.customerName)\" — logged time may be underpriced."
        } else if openJobs.count >= 3 {
            rateTip = "\(openJobs.count) jobs still waiting for payment — send a reminder from Waiting."
        }

        let headline: String = {
            if paidJobs.count == jobs.count {
                return "All tracked jobs are paid. Nice work."
            }
            if waitingTotal > 0 {
                return "You have money waiting on \(openJobs.count) job(s)."
            }
            return "Track profit and waiting balances at a glance."
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
