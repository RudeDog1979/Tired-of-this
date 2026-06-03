//
//  SimpleStudioModels.swift
//  BuxMuse
//
//  Simple Studio — data types for informal workers (offline JSON store).
//

import Foundation

// MARK: - Studio mode & persona

public enum StudioMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case simple
    case pro

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .simple: return "Simple Studio"
        case .pro: return "Pro Studio"
        }
    }

    public var subtitle: String {
        switch self {
        case .simple:
            return "Track jobs, advances, and who owes you — free."
        case .pro:
            return "Full tax, PDF invoices, projects, and analytics."
        }
    }

    /// Short premium badge label shown on the Studio wordmark.
    public var tierBadgeLabel: String? {
        switch self {
        case .simple: return nil
        case .pro: return "PRO"
        }
    }
}

public enum StudioPersona: String, Codable, CaseIterable, Identifiable, Sendable {
    case tasksAndGigs
    case jobsAndRepairs
    case driving
    case shop
    case lending
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tasksAndGigs: return "Tasks & Gigs"
        case .jobsAndRepairs: return "Jobs & Repairs"
        case .driving: return "Driving & Delivery"
        case .shop: return "Shop & Sales"
        case .lending: return "Lending & Susu"
        case .other: return "Other Work"
        }
    }

    public var subtitle: String {
        switch self {
        case .tasksAndGigs: return "Platform jobs, tips, travel"
        case .jobsAndRepairs: return "Materials, advances, job sites"
        case .driving: return "Trips, fuel, fares"
        case .shop: return "Daily sales and stock"
        case .lending: return "Track loans and repayments"
        case .other: return "General work tracking"
        }
    }

    public var systemImage: String {
        switch self {
        case .tasksAndGigs: return "wrench.and.screwdriver"
        case .jobsAndRepairs: return "hammer.fill"
        case .driving: return "car.fill"
        case .shop: return "storefront.fill"
        case .lending: return "banknote.fill"
        case .other: return "briefcase.fill"
        }
    }
}

// MARK: - Entry kinds

public enum SimpleEntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case income
    case expense
    case job
    case advanceReceived
    case owedToMe
    case iOwe
    case lent
    case repaymentReceived

    public var id: String { rawValue }

    public var logTitle: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        case .job: return "Job"
        case .advanceReceived: return "Advance"
        case .owedToMe: return "They owe me"
        case .iOwe: return "I owe"
        case .lent: return "I lent"
        case .repaymentReceived: return "Repayment"
        }
    }

    public var systemImage: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .job: return "hammer.fill"
        case .advanceReceived: return "hand.raised.fill"
        case .owedToMe: return "person.fill.questionmark"
        case .iOwe: return "person.fill.xmark"
        case .lent: return "arrow.up.right.circle.fill"
        case .repaymentReceived: return "arrow.down.left.circle.fill"
        }
    }

    public static var dailyLogKinds: [SimpleEntryKind] {
        [.income, .expense, .job, .advanceReceived, .owedToMe, .iOwe]
    }

    public static var lendingKinds: [SimpleEntryKind] {
        [.lent, .repaymentReceived, .owedToMe, .iOwe]
    }
}

public enum SimplePaymentStatus: String, Codable, CaseIterable, Sendable {
    case paid
    case unpaid
    case partial
}

// MARK: - Persisted records

public struct SimpleStudioEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: SimpleEntryKind
    public var amount: Decimal
    public var customerName: String
    public var customerId: UUID?
    public var jobLabel: String?
    public var note: String?
    public var paymentStatus: SimplePaymentStatus
    public var platformFee: Decimal?
    public var tip: Decimal?
    public var materials: Decimal?
    public var petrol: Decimal?
    public var transport: Decimal?
    public var advanceAmount: Decimal?
    /// Full price agreed with the customer (quote).
    public var agreedPrice: Decimal?
    /// One price for whole job vs paid by the hour (Simple work clock).
    public var payStyle: SimpleJobPayStyle?
    /// Hourly rate when `payStyle` is `.byTheHour`.
    public var hourlyRate: Decimal?
    public var linkedJobId: UUID?
    public var linkedInvoiceId: UUID?
    /// Stopwatch time logged against this job (Simple Studio Log Time).
    public var loggedSeconds: TimeInterval?
    /// Customer-agreed time for the job (lock-screen walker + optional auto-pause).
    public var plannedWorkSeconds: TimeInterval?
    /// Pause the work clock when planned time is reached (default on).
    public var pauseWhenPlanEnds: Bool?
    public var sourcePhotoPath: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: SimpleEntryKind,
        amount: Decimal,
        customerName: String = "",
        customerId: UUID? = nil,
        jobLabel: String? = nil,
        note: String? = nil,
        paymentStatus: SimplePaymentStatus = .paid,
        platformFee: Decimal? = nil,
        tip: Decimal? = nil,
        materials: Decimal? = nil,
        petrol: Decimal? = nil,
        transport: Decimal? = nil,
        advanceAmount: Decimal? = nil,
        agreedPrice: Decimal? = nil,
        payStyle: SimpleJobPayStyle? = nil,
        hourlyRate: Decimal? = nil,
        linkedJobId: UUID? = nil,
        linkedInvoiceId: UUID? = nil,
        loggedSeconds: TimeInterval? = nil,
        plannedWorkSeconds: TimeInterval? = nil,
        pauseWhenPlanEnds: Bool? = nil,
        sourcePhotoPath: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.customerName = customerName
        self.customerId = customerId
        self.jobLabel = jobLabel
        self.note = note
        self.paymentStatus = paymentStatus
        self.platformFee = platformFee
        self.tip = tip
        self.materials = materials
        self.petrol = petrol
        self.transport = transport
        self.advanceAmount = advanceAmount
        self.agreedPrice = agreedPrice
        self.payStyle = payStyle
        self.hourlyRate = hourlyRate
        self.linkedJobId = linkedJobId
        self.linkedInvoiceId = linkedInvoiceId
        self.loggedSeconds = loggedSeconds
        self.plannedWorkSeconds = plannedWorkSeconds
        self.pauseWhenPlanEnds = pauseWhenPlanEnds
        self.sourcePhotoPath = sourcePhotoPath
        self.createdAt = createdAt
    }

    public var jobCosts: Decimal {
        [materials, petrol, transport, platformFee].compactMap { $0 }.reduce(0, +)
    }

    /// Total customer payments received for this job.
    public var paidSoFar: Decimal { amount }

    /// Amount still owed when a full agreed price exists.
    public var jobBalanceDue: Decimal {
        guard kind == .job else { return 0 }
        if resolvedPayStyle == .byTheHour, let rate = hourlyRate, rate > 0 {
            let earned = SimpleStudioTimePayEngine.earnings(seconds: loggedSeconds ?? 0, hourlyRate: rate)
            return max(0, earned - paidSoFar)
        }
        if let agreed = agreedPrice {
            return max(0, agreed - paidSoFar)
        }
        return paymentStatus == .paid ? 0 : amount
    }

    public var isJobFullyPaid: Bool {
        guard kind == .job else { return paymentStatus == .paid }
        if let agreed = agreedPrice { return paidSoFar >= agreed }
        return paymentStatus == .paid
    }

    /// Profit after job costs — based on money in hand today.
    public var keptSoFar: Decimal {
        guard kind == .job || kind == .income else { return netKept }
        return paidSoFar + (tip ?? 0) - jobCosts
    }

    /// Profit if the customer pays the full agreed amount.
    public var projectedKept: Decimal {
        guard kind == .job else { return netKept }
        let revenue: Decimal = {
            if resolvedPayStyle == .byTheHour, let rate = hourlyRate, rate > 0 {
                return SimpleStudioTimePayEngine.earnings(seconds: loggedSeconds ?? 0, hourlyRate: rate)
            }
            return agreedPrice ?? paidSoFar
        }()
        return revenue + (tip ?? 0) - jobCosts
    }

    public func jobBreakdown() -> SimpleJobBreakdown? {
        guard kind == .job else { return nil }
        let agreed = agreedPrice ?? amount
        return SimpleJobBreakdown(
            agreed: agreed,
            paidSoFar: paidSoFar,
            spent: jobCosts,
            balanceDue: jobBalanceDue,
            keptSoFar: keptSoFar,
            projectedKept: projectedKept,
            hasQuote: agreedPrice != nil
        )
    }

    public var netKept: Decimal {
        switch kind {
        case .income, .repaymentReceived:
            return amount + (tip ?? 0) - jobCosts
        case .job:
            return keptSoFar
        case .expense, .iOwe, .lent:
            return -amount
        case .advanceReceived:
            return 0
        case .owedToMe:
            return paymentStatus == .paid ? amount : 0
        }
    }
}

public struct SimpleJobBreakdown: Equatable, Sendable {
    public var agreed: Decimal
    public var paidSoFar: Decimal
    public var spent: Decimal
    public var balanceDue: Decimal
    public var keptSoFar: Decimal
    public var projectedKept: Decimal
    public var hasQuote: Bool
}

public struct SimpleCustomerMemory: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var phone: String?
    public var notes: String?
    public var lastAmount: Decimal?
    public var lastJobLabel: String?
    public var lastSeen: Date
    public var totalEarned: Decimal
    public var outstandingBalance: Decimal
    public var completedJobs: Int

    public init(
        id: UUID = UUID(),
        name: String,
        phone: String? = nil,
        notes: String? = nil,
        lastAmount: Decimal? = nil,
        lastJobLabel: String? = nil,
        lastSeen: Date = Date(),
        totalEarned: Decimal = 0,
        outstandingBalance: Decimal = 0,
        completedJobs: Int = 0
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.notes = notes
        self.lastAmount = lastAmount
        self.lastJobLabel = lastJobLabel
        self.lastSeen = lastSeen
        self.totalEarned = totalEarned
        self.outstandingBalance = outstandingBalance
        self.completedJobs = completedJobs
    }
}

public enum SimpleInvoiceStatus: String, Codable, Sendable {
    case draft
    case sent
    case paid
}

public struct SimpleInvoice: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var customerName: String
    public var customerId: UUID?
    public var amount: Decimal
    public var jobDescription: String
    public var status: SimpleInvoiceStatus
    public var createdAt: Date
    public var sharedAt: Date?
    public var paidAt: Date?
    public var linkedEntryId: UUID?

    public init(
        id: UUID = UUID(),
        customerName: String,
        customerId: UUID? = nil,
        amount: Decimal,
        jobDescription: String,
        status: SimpleInvoiceStatus = .sent,
        createdAt: Date = Date(),
        sharedAt: Date? = nil,
        paidAt: Date? = nil,
        linkedEntryId: UUID? = nil
    ) {
        self.id = id
        self.customerName = customerName
        self.customerId = customerId
        self.amount = amount
        self.jobDescription = jobDescription
        self.status = status
        self.createdAt = createdAt
        self.sharedAt = sharedAt
        self.paidAt = paidAt
        self.linkedEntryId = linkedEntryId
    }
}

public struct SimpleStudioSnapshot: Codable, Equatable, Sendable {
    public var entries: [SimpleStudioEntry]
    public var customers: [SimpleCustomerMemory]
    public var invoices: [SimpleInvoice]
    public var hourlyRateHint: Decimal?
    public var businessCard: SimpleBusinessCard?

    public init(
        entries: [SimpleStudioEntry] = [],
        customers: [SimpleCustomerMemory] = [],
        invoices: [SimpleInvoice] = [],
        hourlyRateHint: Decimal? = nil,
        businessCard: SimpleBusinessCard? = nil
    ) {
        self.entries = entries
        self.customers = customers
        self.invoices = invoices
        self.hourlyRateHint = hourlyRateHint
        self.businessCard = businessCard
    }
}

// MARK: - Business card

public struct SimpleBusinessCard: Codable, Equatable, Sendable {
    public var name: String
    public var tagline: String
    public var phone: String
    public var email: String
    public var skills: String
    public var photoPath: String?

    public init(
        name: String = "",
        tagline: String = "",
        phone: String = "",
        email: String = "",
        skills: String = "",
        photoPath: String? = nil
    ) {
        self.name = name
        self.tagline = tagline
        self.phone = phone
        self.email = email
        self.skills = skills
        self.photoPath = photoPath
    }
}

// MARK: - Navigation

public enum SimpleStudioDetailDestination: Identifiable, Equatable {
    case entry(UUID)
    case invoice(UUID)
    case person(UUID)

    public var id: String {
        switch self {
        case .entry(let id): return "entry-\(id.uuidString)"
        case .invoice(let id): return "invoice-\(id.uuidString)"
        case .person(let id): return "person-\(id.uuidString)"
        }
    }
}

// MARK: - UI snapshots

public struct SimpleWaitingItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var customerName: String
    public var amount: Decimal
    public var amountFormatted: String
    public var jobLabel: String
    public var daysWaiting: Int
    public var advanceBalance: Decimal?
    public var advanceBalanceFormatted: String?
}

public struct SimpleRecentItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var amountFormatted: String
    public var isPositive: Bool
    public var hasPhoto: Bool
    public var photoPath: String?
    public var timestamp: Date
}

public struct SimpleChartSlice: Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var value: Decimal
    public var valueFormatted: String
    public var fraction: Double
}

public struct SimpleTaxTileDisplay: Equatable, Sendable {
    public var made: String
    public var spent: String
    public var keep: String
    public var mightOwe: String
    public var coachLine: String

    public static let empty = SimpleTaxTileDisplay(
        made: "—",
        spent: "—",
        keep: "—",
        mightOwe: "—",
        coachLine: "Log work to see your numbers."
    )
}

public struct SimpleStudioHubDisplay: Equatable, Sendable {
    public var businessTitle: String
    public var todayKeptFormatted: String
    public var madeFormatted: String
    public var spentFormatted: String
    public var waitingFormatted: String
    public var oweFormatted: String
    public var spentFootnote: String
    public var waitingItems: [SimpleWaitingItem]
    public var iOweItems: [SimpleWaitingItem]
    public var recentItems: [SimpleRecentItem]
    public var monthChartSlices: [SimpleChartSlice]
    public var taxTile: SimpleTaxTileDisplay
    public var isEmpty: Bool

    public static let empty = SimpleStudioHubDisplay(
        businessTitle: "Your Work",
        todayKeptFormatted: "—",
        madeFormatted: "—",
        spentFormatted: "—",
        waitingFormatted: "—",
        oweFormatted: "—",
        spentFootnote: "materials + petrol",
        waitingItems: [],
        iOweItems: [],
        recentItems: [],
        monthChartSlices: [],
        taxTile: .empty,
        isEmpty: true
    )
}

public struct SimpleJobPocketDisplay: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var customerName: String
    public var jobLabel: String
    public var agreedFormatted: String
    public var paidFormatted: String
    public var spentFormatted: String
    public var waitingFormatted: String
    public var keptFormatted: String
    public var projectedKeptFormatted: String
    public var keptFraction: Double
}

public struct SimpleMyMoneyDisplay: Equatable, Sendable {
    public var monthSlices: [SimpleChartSlice]
    public var waitingItems: [SimpleWaitingItem]
    public var iOweItems: [SimpleWaitingItem]
    public var jobPockets: [SimpleJobPocketDisplay]
    public var taxTile: SimpleTaxTileDisplay

    public static let empty = SimpleMyMoneyDisplay(
        monthSlices: [],
        waitingItems: [],
        iOweItems: [],
        jobPockets: [],
        taxTile: .empty
    )
}

// MARK: - Scan draft (Phase C)

public enum SimpleScanField: String, CaseIterable, Identifiable, Sendable {
    case kind
    case amount
    case customer
    case jobLabel
    case note
    case payment

    public var id: String { rawValue }

    public var chipTitle: String {
        switch self {
        case .kind: return "Type"
        case .amount: return "Amount"
        case .customer: return "Who"
        case .jobLabel: return "What"
        case .note: return "Note"
        case .payment: return "Paid?"
        }
    }

    public var systemImage: String {
        switch self {
        case .kind: return "tag.fill"
        case .amount: return "dollarsign.circle.fill"
        case .customer: return "person.fill"
        case .jobLabel: return "hammer.fill"
        case .note: return "note.text"
        case .payment: return "checkmark.circle.fill"
        }
    }
}

public struct SimpleScanDraft: Equatable, Sendable {
    public var kind: SimpleEntryKind
    public var amount: Decimal
    public var customerName: String
    public var jobLabel: String
    public var note: String
    public var date: Date
    public var paymentStatus: SimplePaymentStatus

    public init(
        kind: SimpleEntryKind = .income,
        amount: Decimal = 0,
        customerName: String = "",
        jobLabel: String = "",
        note: String = "",
        date: Date = Date(),
        paymentStatus: SimplePaymentStatus = .paid
    ) {
        self.kind = kind
        self.amount = amount
        self.customerName = customerName
        self.jobLabel = jobLabel
        self.note = note
        self.date = date
        self.paymentStatus = paymentStatus
    }

    public func asEntry(sourcePhotoPath: String?) -> SimpleStudioEntry {
        SimpleStudioEntry(
            kind: kind,
            amount: amount,
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            jobLabel: jobLabel.isEmpty ? nil : jobLabel,
            note: note.isEmpty ? nil : note,
            paymentStatus: kind == .owedToMe || kind == .job ? paymentStatus : .paid,
            sourcePhotoPath: sourcePhotoPath,
            createdAt: date
        )
    }

    public init(entry: SimpleStudioEntry) {
        kind = entry.kind
        amount = entry.amount
        customerName = entry.customerName
        jobLabel = entry.jobLabel ?? ""
        note = entry.note ?? ""
        date = entry.createdAt
        paymentStatus = entry.paymentStatus
    }
}
