//
//  TaxCountryHeuristics.swift
//  BuxMuse
//
//  Country- and currency-aware income band + VAT turnover heuristics for Tax Studio.
//

import Foundation

enum TaxCountryHeuristics {
    private static let baselineUSDBands: [Decimal] = [10_000, 50_000, 100_000]
    private static let baselineUSDVATThreshold: Decimal = 85_000
    private static let vatProximityRatio: Decimal = 0.82

    private static let countryAliases: [String: String] = [
        "UK": "GB",
        "EL": "GR"
    ]

    /// Annual income band lower bounds in local currency (preset catalog countries).
    private static let incomeBandOverrides: [String: [Decimal]] = [
        "GB": [10_000, 50_000, 100_000],
        "US": [11_600, 47_150, 100_525],
        "DO": [416_220, 624_329, 867_123],
        "MX": [350_000, 1_000_000, 3_500_000],
        "CA": [15_000, 55_000, 111_000],
        "AU": [18_200, 45_000, 120_000],
        "DE": [11_604, 45_000, 90_000],
        "FR": [11_000, 27_000, 75_000],
        "ES": [12_450, 35_000, 60_000],
        "IT": [15_000, 35_000, 60_000],
        "IN": [300_000, 700_000, 1_500_000],
        "BR": [22_000, 55_000, 120_000],
        "JP": [1_600_000, 4_500_000, 9_000_000],
        "KR": [14_000_000, 40_000_000, 88_000_000],
        "SG": [20_000, 60_000, 120_000],
        "AR": [2_000_000, 8_000_000, 20_000_000],
        "CL": [8_000_000, 20_000_000, 50_000_000],
        "CO": [40_000_000, 100_000_000, 250_000_000],
        "PE": [35_000, 90_000, 180_000],
        "CN": [60_000, 200_000, 500_000],
        "DZ": [240_000, 720_000, 1_800_000],
        "AL": [1_200_000, 3_600_000, 9_000_000],
        "AM": [4_800_000, 14_400_000, 36_000_000],
        "AO": [8_300_000, 24_900_000, 62_250_000],
        "AF": [7_000_000, 21_000_000, 52_500_000],
        "AD": [9_200, 27_600, 69_000],
        "AG": [27_000, 81_000, 202_500],
        "AI": [27_000, 81_000, 202_500],
        "AW": [18_000, 54_000, 135_000]
    ]

    /// Known annual turnover VAT/GST registration thresholds in local currency.
    private static let vatThresholdOverrides: [String: Decimal] = [
        "GB": 85_000,
        "DE": 22_000,
        "FR": 85_000,
        "ES": 85_000,
        "IT": 85_000,
        "AU": 75_000,
        "CA": 30_000,
        "IN": 2_000_000,
        "SG": 1_000_000,
        "MX": 1_200_000,
        "DO": 4_062_000,
        "BR": 1_800_000,
        "JP": 10_000_000,
        "KR": 80_000_000,
        "AR": 75_000_000,
        "CL": 50_000_000,
        "CO": 200_000_000,
        "PE": 200_000,
        "CN": 5_000_000
    ]

    private static let noVATTurnoverThreshold: Set<String> = ["US", "AQ"]

    /// Approximate local currency units per 1 USD — scales baseline bands for uncatalogued countries.
    private static let currencyUnitsPerUSD: [String: Decimal] = [
        "USD": 1, "GBP": 0.79, "EUR": 0.92, "DOP": 59, "MXN": 17, "CAD": 1.36,
        "AUD": 1.55, "JPY": 150, "INR": 83, "BRL": 5.0, "ARS": 900, "CLP": 950,
        "COP": 4000, "PEN": 3.7, "SGD": 1.34, "KRW": 1350, "CNY": 7.2,
        "DZD": 135, "ALL": 95, "AMD": 390, "AOA": 830, "AWG": 1.79, "XCD": 2.7,
        "AFN": 70
    ]

    static func normalizeCountryCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return countryAliases[trimmed] ?? trimmed
    }

    static func incomeBandLimits(countryCode: String, currencyCode: String) -> [Decimal] {
        let code = normalizeCountryCode(countryCode)
        if let bands = incomeBandOverrides[code] { return bands }
        let scale = currencyUnitsPerUSD[currencyCode.uppercased()] ?? 1
        return baselineUSDBands.map { $0 * scale }
    }

    static func vatRegistrationThreshold(countryCode: String, currencyCode: String) -> Decimal? {
        let code = normalizeCountryCode(countryCode)
        if noVATTurnoverThreshold.contains(code) { return nil }
        if let threshold = vatThresholdOverrides[code] { return threshold }
        let normalizedCurrency = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCurrency.isEmpty, normalizedCurrency != "NONE" else { return nil }
        let scale = currencyUnitsPerUSD[normalizedCurrency] ?? 1
        return baselineUSDVATThreshold * scale
    }

    static func isApproachingVATThreshold(
        rollingGross: Decimal,
        countryCode: String,
        currencyCode: String
    ) -> Bool {
        guard let threshold = vatRegistrationThreshold(countryCode: countryCode, currencyCode: currencyCode) else {
            return false
        }
        return rollingGross >= threshold * vatProximityRatio
    }
}
