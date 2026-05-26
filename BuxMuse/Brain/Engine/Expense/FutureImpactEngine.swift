//
//  FutureImpactEngine.swift
//  BuxMuse
//
//  Projects 1-year and 5-year costs.
//

import Foundation

struct FutureImpactEngine {
    static func project(amount: Decimal) -> (impact1Y: Double, impact5Y: Double, summary: String) {
        let val = abs(NSDecimalNumber(decimal: amount).doubleValue)
        let cost1Y = val * 12
        let cost5Y = val * 60
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        
        let display1Y = formatter.string(from: NSNumber(value: cost1Y)) ?? "$\(Int(cost1Y))"
        let display5Y = formatter.string(from: NSNumber(value: cost5Y)) ?? "$\(Int(cost5Y))"
        
        let summary = "If repeated monthly, this costs \(display1Y) a year and \(display5Y) over 5 years."
        return (cost1Y, cost5Y, summary)
    }
}
