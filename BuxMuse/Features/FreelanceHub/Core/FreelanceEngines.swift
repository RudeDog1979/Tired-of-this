//
//  FreelanceEngines.swift
//  BuxMuse
//
//  Fully on-device business intelligence engines ("BuxMuse Brain" freelance modules).
//

import Foundation
import SwiftUI
import Vision
import PDFKit

// MARK: - 1. Client Intelligence Engine

public struct ClientHealthScore: Codable, Equatable {
    public var profitabilityScore: Double // 0.0 - 100.0
    public var reliabilityScore: Double    // 0.0 - 100.0
    public var stressScore: Double         // 0.0 - 100.0
    public var overallScore: Double        // 0.0 - 100.0
}

public final class FreelanceClientEngine {
    public static func analyze(
        client: FreelanceClient,
        invoices: [FreelanceInvoice],
        projects: [FreelanceProject],
        receipts: [FreelanceReceipt]
    ) -> (lifetimeValue: Decimal, averagePaymentDelay: TimeInterval, health: ClientHealthScore) {
        
        let clientInvoices = invoices.filter { $0.clientId == client.id }
        let clientReceipts = receipts.filter { $0.linkedClientId == client.id }
        
        // 1. Lifetime Value (Paid Invoices)
        let ltv = clientInvoices
            .filter { $0.status == .paid }
            .reduce(Decimal(0)) { $0 + $1.total }
            
        // 2. Average Payment Delay
        var totalDelay: TimeInterval = 0
        var paidCount = 0
        
        for invoice in clientInvoices where invoice.status == .paid {
            if let payDate = invoice.paymentDate {
                let delay = payDate.timeIntervalSince(invoice.issueDate)
                totalDelay += delay
                paidCount += 1
            }
        }
        let avgDelay = paidCount > 0 ? (totalDelay / Double(paidCount)) : 0
        
        // 3. Profitability Score (Revenue vs Direct Expenses)
        let directCost = clientReceipts.reduce(Decimal(0)) { $0 + $1.amount }
        let totalRevenue = clientInvoices.reduce(Decimal(0)) { $0 + $1.total }
        
        let profitRatio = totalRevenue > 0 ? Double(truncating: ((totalRevenue - directCost) / totalRevenue) as NSDecimalNumber) : 1.0
        let profitabilityScore = min(100.0, max(0.0, profitRatio * 100.0))
        
        // 4. Reliability Score (Overdue invoices / Late payments)
        let overdueCount = clientInvoices.filter { $0.status == .overdue }.count
        let totalInvoices = max(1, clientInvoices.count)
        let onTimeRatio = Double(totalInvoices - overdueCount) / Double(totalInvoices)
        let reliabilityScore = min(100.0, max(0.0, onTimeRatio * 100.0))
        
        // 5. Stress Score
        let stressScore: Double = client.isFlaggedForStress ? 90.0 : (clientInvoices.filter { $0.status == .overdue }.count > 0 ? 40.0 : 10.0)
        
        // 6. Overall Health Score
        let overall = (profitabilityScore * 0.4) + (reliabilityScore * 0.4) + ((100.0 - stressScore) * 0.2)
        
        let health = ClientHealthScore(
            profitabilityScore: profitabilityScore,
            reliabilityScore: reliabilityScore,
            stressScore: stressScore,
            overallScore: min(100.0, max(0.0, overall))
        )
        
        return (ltv, avgDelay, health)
    }
}

// MARK: - 2. Invoice Engine

public struct InvoiceIntelligence: Codable, Equatable {
    public var paymentPredictionDays: Int
    public var latePaymentRisk: Double // 0.0 - 1.0 (Percentage)
    public var rateWarning: String?
}

public final class FreelanceInvoiceEngine {
    public static func computeTotals(
        items: [FreelanceInvoiceLineItem],
        vatRate: Decimal?,
        profile: FreelanceProfile
    ) -> (subtotal: Decimal, taxAmount: Decimal, total: Decimal) {
        let subtotal = items.reduce(Decimal(0)) { $0 + $1.total }
        var taxAmount: Decimal = 0
        
        if let vat = vatRate {
            let taxableSum = items.filter { $0.isTaxable }.reduce(Decimal(0)) { $0 + $1.total }
            taxAmount = taxableSum * (vat / 100.0)
        }
        
        let total = subtotal + taxAmount
        return (subtotal, taxAmount, total)
    }
    
    public static func analyzeInvoice(
        invoice: FreelanceInvoice,
        client: FreelanceClient?,
        profile: FreelanceProfile,
        historicalInvoices: [FreelanceInvoice]
    ) -> InvoiceIntelligence {
        
        var predictionDays = client?.paymentTermsDays ?? profile.defaultInvoicePaymentTerms
        var lateRisk = 0.0
        
        if let client = client {
            let clientHistory = historicalInvoices.filter { $0.clientId == client.id }
            let overdueHistory = clientHistory.filter { $0.status == .overdue }
            
            if !clientHistory.isEmpty {
                let overdueRatio = Double(overdueHistory.count) / Double(clientHistory.count)
                lateRisk = overdueRatio
                predictionDays += Int(overdueRatio * 15.0) // Predict higher latency if history of late payments
            }
            if client.isFlaggedForStress {
                lateRisk = max(lateRisk, 0.75)
                predictionDays += 10
            }
        }
        
        // Rate warnings (Underpricing analysis)
        var warning: String? = nil
        if let defaultHourly = profile.defaultHourlyRate {
            for item in invoice.lineItems where item.description.lowercased().contains("hour") || item.description.lowercased().contains("rate") {
                if item.unitPrice < defaultHourly {
                    warning = "Billing rate (\(item.unitPrice)) is below your default hourly rate (\(defaultHourly))."
                }
            }
        }
        
        return InvoiceIntelligence(
            paymentPredictionDays: predictionDays,
            latePaymentRisk: min(1.0, max(0.0, lateRisk)),
            rateWarning: warning
        )
    }
}

// MARK: - 3. Project & Time Engine

public final class FreelanceProjectEngine {
    public static func analyzeProject(
        project: FreelanceProject,
        receipts: [FreelanceReceipt]
    ) -> (
        totalTime: TimeInterval,
        billableTime: TimeInterval,
        projectedRevenue: Decimal,
        projectedExpenses: Decimal,
        projectedProfit: Decimal,
        effectiveHourlyRate: Decimal,
        isOverrunRisk: Bool
    ) {
        let totalEntries = project.timeEntries
        let totalDuration = totalEntries.reduce(0.0) { $0 + $1.duration }
        let billableDuration = totalEntries.filter { $0.isBillable }.reduce(0.0) { $0 + $1.duration }
        
        // Project Direct Expenses
        let projectExpenses = receipts
            .filter { project.expenseIds.contains($0.id) || $0.linkedProjectId == project.id }
            .reduce(Decimal(0)) { $0 + $1.amount }
            
        // Revenues
        var revenue: Decimal = 0
        let hourly = project.hourlyRate ?? 0
        
        if let fixed = project.fixedFee {
            revenue = fixed
        } else {
            revenue = Decimal(billableDuration / 3600.0) * hourly
        }
        
        let profit = revenue - projectExpenses
        let billableHours = Decimal(billableDuration / 3600.0)
        let effectiveRate = billableHours > 0 ? (revenue / billableHours) : 0
        
        // Overrun risk: If total hours logged > 100 on fixed fee, or billable is extremely low
        var overrun = false
        if project.fixedFee != nil && (totalDuration / 3600.0) > 80 {
            overrun = true
        }
        
        return (
            totalDuration,
            billableDuration,
            revenue,
            projectExpenses,
            profit,
            effectiveRate,
            overrun
        )
    }
}

// MARK: - 4. Receipt scanner / OCR Document Intelligence

public final class FreelanceReceiptEngine {
    public static func parseReceipt(
        image: UIImage,
        completion: @escaping (Result<(merchant: String, amount: Decimal, date: Date, vat: Decimal?), Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "FreelanceReceiptEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid CGImage"])))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(NSError(domain: "FreelanceReceiptEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text blocks detected"])))
                return
            }
            
            var allLines: [String] = []
            for obs in observations {
                if let candidate = obs.topCandidates(1).first {
                    allLines.append(candidate.string)
                }
            }
            
            // Local parsing heuristics
            let (merchant, amount, date, vat) = parseHeuristics(from: allLines)
            completion(.success((merchant, amount, date, vat)))
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
    
    private static func parseHeuristics(from lines: [String]) -> (merchant: String, amount: Decimal, date: Date, vat: Decimal?) {
        var merchant = "Unknown Merchant"
        var amount: Decimal = 0
        var date = Date()
        var vatAmount: Decimal? = nil
        
        // 1. Merchant Heuristic (usually first 1-2 lines)
        if let first = lines.first, first.count > 2 {
            merchant = first
        }
        
        // RegEx matching variables
        let amountPattern = #"\b\d+[\.,]\d{2}\b"#
        let datePattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#
        
        let amountRegex = try? NSRegularExpression(pattern: amountPattern)
        let dateRegex = try? NSRegularExpression(pattern: datePattern)
        
        var foundAmounts: [Decimal] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: "USD", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check Date
            if let match = dateRegex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                if let range = Range(match.range, in: line), let parsedDate = parseDateString(String(line[range])) {
                    date = parsedDate
                }
            }
            
            // Find Decimal Values
            let range = NSRange(location: 0, length: cleanLine.utf16.count)
            amountRegex?.enumerateMatches(in: cleanLine, options: [], range: range) { match, _, _ in
                if let match = match, let matchRange = Range(match.range, in: cleanLine) {
                    let numStr = cleanLine[matchRange].replacingOccurrences(of: ",", with: ".")
                    if let decimal = Decimal(string: String(numStr)) {
                        foundAmounts.append(decimal)
                    }
                }
            }
            
            // Check VAT keyword
            if line.lowercased().contains("vat") || line.lowercased().contains("tax") {
                if let match = amountRegex?.firstMatch(in: cleanLine, options: [], range: NSRange(location: 0, length: cleanLine.utf16.count)) {
                    if let range = Range(match.range, in: cleanLine) {
                        let numStr = cleanLine[range].replacingOccurrences(of: ",", with: ".")
                        vatAmount = Decimal(string: String(numStr))
                    }
                }
            }
        }
        
        // Total Amount: usually the highest parsed decimal value on the ticket
        if let maxVal = foundAmounts.max() {
            amount = maxVal
        }
        
        return (merchant, amount, date, vatAmount)
    }
    
    private static func parseDateString(_ str: String) -> Date? {
        let formats = ["MM/dd/yyyy", "dd/MM/yyyy", "MM-dd-yyyy", "yyyy/MM/dd", "MM/dd/yy"]
        let formatter = DateFormatter()
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: str) {
                return d
            }
        }
        return nil
    }
}

// MARK: - 5. Dynamic Tax & Simulator Engine

public struct TaxSimulationResult: Codable, Equatable {
    public var totalGrossIncome: Decimal
    public var totalDeductions: Decimal
    public var taxableIncome: Decimal
    public var estimatedTax: Decimal
    public var estimatedVat: Decimal
    public var netIncome: Decimal
    public var effectiveTaxRate: Double // e.g. 0.22 for 22%
}

public final class FreelanceTaxEngine {
    public static func computeEstimatedTax(
        profile: FreelanceProfile,
        taxProfile: FreelanceTaxProfile,
        invoices: [FreelanceInvoice],
        receipts: [FreelanceReceipt]
    ) -> TaxSimulationResult {
        
        // 1. Gather Gross Income (Paid & Sent Invoices in current Tax period)
        let activeInvoices = invoices.filter { $0.status == .paid || $0.status == .sent || $0.status == .overdue }
        let totalGross = activeInvoices.reduce(Decimal(0)) { $0 + $1.subtotal }
        
        // 2. Gather Deductible Expenses
        let deductibleReceipts = receipts.filter { $0.isDeductible }
        let totalDeductions = deductibleReceipts.reduce(Decimal(0)) { sum, receipt in
            let categoryRule = taxProfile.deductionCategories.first { $0.categoryId == receipt.category }
            let deductRatio: Decimal = {
                switch categoryRule?.deductibilityType {
                case .full: return 1.0
                case .partial: return 0.5
                case .limited: return 0.3
                default: return 1.0
                }
            }()
            return sum + (receipt.amount * deductRatio)
        }
        
        // 3. Taxable Income
        let taxableIncome = max(Decimal(0), totalGross - totalDeductions)
        
        // 4. Bracket Income Tax Calculation
        var tax: Decimal = 0
        var remainingIncome = taxableIncome
        
        let sortedBrackets = taxProfile.incomeTaxRules.sorted { $0.lowerBound < $1.lowerBound }
        for bracket in sortedBrackets {
            let lower = bracket.lowerBound
            let upper = bracket.upperBound
            let rate = bracket.rate
            
            if remainingIncome > 0 {
                let taxableInThisBracket: Decimal
                if let upper = upper {
                    let bracketLimit = upper - lower
                    taxableInThisBracket = min(remainingIncome, bracketLimit)
                } else {
                    taxableInThisBracket = remainingIncome
                }
                tax += taxableInThisBracket * rate
                remainingIncome -= taxableInThisBracket
            }
        }
        
        // 5. VAT calculation
        var vatOwed: Decimal = 0
        if profile.vatRegistered {
            // VAT generated on invoices minus VAT paid on expenses
            let invoiceVat = activeInvoices.reduce(Decimal(0)) { $0 + ($1.taxAmount) }
            let expenseVat = receipts.reduce(Decimal(0)) { $0 + ($1.vatAmount ?? 0) }
            vatOwed = max(0, invoiceVat - expenseVat)
        }
        
        let net = totalGross - tax - vatOwed - totalDeductions
        let overallTaxFraction = totalGross > 0 ? Double(truncating: ((tax + vatOwed) / totalGross) as NSDecimalNumber) : 0.0
        
        return TaxSimulationResult(
            totalGrossIncome: totalGross,
            totalDeductions: totalDeductions,
            taxableIncome: taxableIncome,
            estimatedTax: tax,
            estimatedVat: vatOwed,
            netIncome: net,
            effectiveTaxRate: overallTaxFraction
        )
    }
    
    /// Interactive Simulator for changes: hourly bump, equipment purchases or VAT toggles.
    public static func simulate(
        profile: FreelanceProfile,
        taxProfile: FreelanceTaxProfile,
        baseResult: TaxSimulationResult,
        vatToggled: Bool,
        hypotheticalRateIncrease: Decimal, // in currency units hourly
        hypotheticalHoursCount: Double,     // simulated billed hours
        newPurchasesAmount: Decimal
    ) -> TaxSimulationResult {
        
        var simulatedProfile = profile
        simulatedProfile.vatRegistered = vatToggled
        
        // Extra Simulated Income
        let extraIncome = hypotheticalRateIncrease * Decimal(hypotheticalHoursCount)
        let totalSimGross = baseResult.totalGrossIncome + extraIncome
        
        // Extra Deductions
        let extraDeductions = newPurchasesAmount
        let totalSimDeductions = baseResult.totalDeductions + extraDeductions
        
        let taxableIncome = max(Decimal(0), totalSimGross - totalSimDeductions)
        
        // Bracket calculation
        var tax: Decimal = 0
        var remainingIncome = taxableIncome
        let sortedBrackets = taxProfile.incomeTaxRules.sorted { $0.lowerBound < $1.lowerBound }
        for bracket in sortedBrackets {
            let lower = bracket.lowerBound
            let upper = bracket.upperBound
            let rate = bracket.rate
            
            if remainingIncome > 0 {
                let taxableInThisBracket: Decimal
                if let upper = upper {
                    let bracketLimit = upper - lower
                    taxableInThisBracket = min(remainingIncome, bracketLimit)
                } else {
                    taxableInThisBracket = remainingIncome
                }
                tax += taxableInThisBracket * rate
                remainingIncome -= taxableInThisBracket
            }
        }
        
        // VAT calculation
        var vatOwed: Decimal = 0
        if vatToggled {
            // Apply standard VAT rate (e.g. 20%) to new simulated income
            let simulatedInvoiceVat = baseResult.estimatedVat + (extraIncome * 0.20)
            vatOwed = max(0, simulatedInvoiceVat)
        }
        
        let net = totalSimGross - tax - vatOwed - totalSimDeductions
        let overallTaxFraction = totalSimGross > 0 ? Double(truncating: ((tax + vatOwed) / totalSimGross) as NSDecimalNumber) : 0.0
        
        return TaxSimulationResult(
            totalGrossIncome: totalSimGross,
            totalDeductions: totalSimDeductions,
            taxableIncome: taxableIncome,
            estimatedTax: tax,
            estimatedVat: vatOwed,
            netIncome: net,
            effectiveTaxRate: overallTaxFraction
        )
    }
}

// MARK: - 6. Cashflow & Forecasting Engine

public struct CashflowForecast: Codable, Equatable {
    public var runwayMonths: Double
    public var survivalMonthlyIncomeNeeded: Decimal
    public var projectedInflow30Days: Decimal
    public var historicalBurnRate: Decimal
}

public final class FreelanceCashflowEngine {
    public static func computeForecast(
        invoices: [FreelanceInvoice],
        receipts: [FreelanceReceipt],
        estimatedTax: Decimal
    ) -> CashflowForecast {
        
        let today = Date()
        
        // 1. Project Inflow in next 30 days (Unpaid sent invoices and draft expected ones)
        let inflow30 = invoices
            .filter { ($0.status == .sent || $0.status == .overdue) && $0.dueDate >= today.addingTimeInterval(-30 * 24 * 3600) }
            .reduce(Decimal(0)) { $0 + $1.total }
            
        // 2. Average Monthly Expenses (Burn Rate) over past 90 days
        let past90Receipts = receipts.filter { $0.date >= today.addingTimeInterval(-90 * 24 * 3600) }
        let totalPastExpenses = past90Receipts.reduce(Decimal(0)) { $0 + $1.amount }
        let monthlyBurn = past90Receipts.isEmpty ? Decimal(0) : (totalPastExpenses / 3.0)
        
        // 3. Survival Income Needed = monthly burn + monthly tax portion
        let survivalIncome = monthlyBurn + (estimatedTax / 12.0)
        
        // 4. Current liquidity (paid invoices last 90 days minus expenses last 90 days)
        let paidLast90 = invoices
            .filter { $0.status == .paid && $0.issueDate >= today.addingTimeInterval(-90 * 24 * 3600) }
            .reduce(Decimal(0)) { $0 + $1.total }
        
        let liquidity = paidLast90 - totalPastExpenses
        
        // 5. Runway (months until zero liquidity at average burn)
        let runway: Double
        if monthlyBurn > 0 {
            runway = Double(truncating: (max(Decimal(0), liquidity) / monthlyBurn) as NSDecimalNumber)
        } else {
            runway = liquidity > 0 ? 24.0 : 0.0
        }
        
        return CashflowForecast(
            runwayMonths: min(24.0, max(0.0, runway)),
            survivalMonthlyIncomeNeeded: survivalIncome,
            projectedInflow30Days: inflow30,
            historicalBurnRate: monthlyBurn
        )
    }
}

// MARK: - 7. Deduction Optimization Engine

public struct DeductionOpportunity: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var description: String
    public var estimatedTaxSaving: Decimal
}

public final class FreelanceDeductionEngine {
    public static func computeDeductions(
        receipts: [FreelanceReceipt],
        taxProfile: FreelanceTaxProfile
    ) -> (totalDeductible: Decimal, opportunities: [DeductionOpportunity]) {
        
        let deductibleReceipts = receipts.filter { $0.isDeductible }
        let totalDeductible = deductibleReceipts.reduce(Decimal(0)) { $0 + $1.amount }
        
        var opportunities: [DeductionOpportunity] = []
        
        // 1. Analyze Category Coverage
        let softwareReceipts = receipts.filter { $0.category.lowercased().contains("software") || $0.category.lowercased().contains("cloud") }
        let topTaxRate = taxProfile.incomeTaxRules.map(\.rate).max() ?? Decimal(0)

        if !receipts.isEmpty && softwareReceipts.isEmpty {
            opportunities.append(DeductionOpportunity(
                id: UUID(),
                title: "Software Deductions",
                description: "No software subscriptions logged yet. Business tools you pay for may be deductible based on your tax profile.",
                estimatedTaxSaving: 0
            ))
        }
        
        let largePurchases = receipts.filter { $0.amount > 1000 }
        if !largePurchases.isEmpty && deductibleReceipts.filter({ $0.category.lowercased().contains("hardware") }).isEmpty {
            let largest = largePurchases.map(\.amount).max() ?? 0
            let estimatedSaving = largest * topTaxRate
            opportunities.append(DeductionOpportunity(
                id: UUID(),
                title: "Hardware Write-off Review",
                description: "A large purchase was logged without a hardware category. Review whether it qualifies for accelerated depreciation.",
                estimatedTaxSaving: estimatedSaving
            ))
        }
        
        return (totalDeductible, opportunities)
    }
}

// MARK: - 8. Local Invoice PDF Renderer

public final class FreelanceInvoicePDFRenderer {
    public static func generatePDF(
        invoice: FreelanceInvoice,
        client: FreelanceClient?,
        profile: FreelanceProfile
    ) -> Data {
        let pdfMetaData = [
            "Title": "Invoice \(invoice.invoiceNumber)",
            "Author": profile.businessName
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Standard US Letter Size: 8.5 x 11 inches = 612 x 792 points
        let pageWidth = 612.0
        let pageHeight = 792.0
        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            // 1. Draw Company Header
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 10, weight: .regular)
            let boldFont = UIFont.systemFont(ofSize: 10, weight: .bold)
            
            // Header Text
            let titleString = profile.businessName.isEmpty ? "Business Name" : profile.businessName
            titleString.draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: titleFont])
            
            if !profile.displayName.isEmpty {
                profile.displayName.draw(at: CGPoint(x: 40, y: 70), withAttributes: [.font: bodyFont])
            }
            let countryLine = profile.countryCode
            countryLine.draw(at: CGPoint(x: 40, y: profile.displayName.isEmpty ? 70 : 85), withAttributes: [.font: bodyFont])
            
            // Invoice Label
            let invLabel = "INVOICE"
            let invFont = UIFont.systemFont(ofSize: 20, weight: .bold)
            invLabel.draw(at: CGPoint(x: 480, y: 40), withAttributes: [.font: invFont])
            
            let invNumStr = "Number: \(invoice.invoiceNumber)"
            invNumStr.draw(at: CGPoint(x: 450, y: 65), withAttributes: [.font: bodyFont])
            
            let dateStr = "Date: \(formattedDate(invoice.issueDate))"
            dateStr.draw(at: CGPoint(x: 450, y: 80), withAttributes: [.font: bodyFont])
            
            let dueStr = "Due Date: \(formattedDate(invoice.dueDate))"
            dueStr.draw(at: CGPoint(x: 450, y: 95), withAttributes: [.font: bodyFont])
            
            // Horizontal divider line
            let context = context.cgContext
            context.setStrokeColor(UIColor.gray.cgColor)
            context.setLineWidth(1.0)
            context.move(to: CGPoint(x: 40, y: 120))
            context.addLine(to: CGPoint(x: 572, y: 120))
            context.strokePath()
            
            // 2. Draw Client Section
            let billToFont = UIFont.systemFont(ofSize: 12, weight: .bold)
            "BILL TO:".draw(at: CGPoint(x: 40, y: 135), withAttributes: [.font: billToFont])
            
            let clientName = client?.name ?? "Unknown Client"
            clientName.draw(at: CGPoint(x: 40, y: 155), withAttributes: [.font: boldFont])
            
            let clientEmail = client?.email ?? ""
            clientEmail.draw(at: CGPoint(x: 40, y: 170), withAttributes: [.font: bodyFont])
            
            let clientAddress = client?.address ?? ""
            clientAddress.draw(at: CGPoint(x: 40, y: 185), withAttributes: [.font: bodyFont])
            
            // 3. Draw Grid/Table of Line Items
            context.move(to: CGPoint(x: 40, y: 220))
            context.addLine(to: CGPoint(x: 572, y: 220))
            context.strokePath()
            
            // Table Headers
            "Description".draw(at: CGPoint(x: 40, y: 225), withAttributes: [.font: boldFont])
            "Qty".draw(at: CGPoint(x: 380, y: 225), withAttributes: [.font: boldFont])
            "Unit Price".draw(at: CGPoint(x: 430, y: 225), withAttributes: [.font: boldFont])
            "Total".draw(at: CGPoint(x: 520, y: 225), withAttributes: [.font: boldFont])
            
            context.move(to: CGPoint(x: 40, y: 240))
            context.addLine(to: CGPoint(x: 572, y: 240))
            context.strokePath()
            
            var yOffset = 250.0
            for item in invoice.lineItems {
                item.description.draw(at: CGPoint(x: 40, y: yOffset), withAttributes: [.font: bodyFont])
                String(format: "%.1f", item.quantity).draw(at: CGPoint(x: 380, y: yOffset), withAttributes: [.font: bodyFont])
                "\(invoice.currencyCode) \(item.unitPrice)".draw(at: CGPoint(x: 430, y: yOffset), withAttributes: [.font: bodyFont])
                "\(invoice.currencyCode) \(item.total)".draw(at: CGPoint(x: 520, y: yOffset), withAttributes: [.font: bodyFont])
                
                yOffset += 20.0
            }
            
            context.move(to: CGPoint(x: 40, y: yOffset + 5))
            context.addLine(to: CGPoint(x: 572, y: yOffset + 5))
            context.strokePath()
            
            // 4. Draw Subtotal/VAT/Total
            yOffset += 15.0
            "Subtotal:".draw(at: CGPoint(x: 430, y: yOffset), withAttributes: [.font: boldFont])
            "\(invoice.currencyCode) \(invoice.subtotal)".draw(at: CGPoint(x: 520, y: yOffset), withAttributes: [.font: bodyFont])
            
            if let vat = invoice.vatRate {
                yOffset += 15.0
                "VAT (\(vat)%):".draw(at: CGPoint(x: 430, y: yOffset), withAttributes: [.font: boldFont])
                "\(invoice.currencyCode) \(invoice.taxAmount)".draw(at: CGPoint(x: 520, y: yOffset), withAttributes: [.font: bodyFont])
            }
            
            yOffset += 20.0
            let finalTotalFont = UIFont.systemFont(ofSize: 12, weight: .bold)
            "TOTAL:".draw(at: CGPoint(x: 430, y: yOffset), withAttributes: [.font: finalTotalFont])
            "\(invoice.currencyCode) \(invoice.total)".draw(at: CGPoint(x: 520, y: yOffset), withAttributes: [.font: finalTotalFont])
            
            // 5. Terms / Footer
            "Payment Terms / Notes:".draw(at: CGPoint(x: 40, y: 650), withAttributes: [.font: boldFont])
            let notesText = invoice.notes.isEmpty ? "Payment is due within \(profile.defaultInvoicePaymentTerms) days of invoice date." : invoice.notes
            notesText.draw(in: CGRect(x: 40, y: 665, width: 500, height: 80), withAttributes: [.font: bodyFont])
        }
    }
    
    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
