//
//  SimpleStudioContactHelper.swift
//  BuxMuse
//

import Foundation

enum SimpleStudioContactHelper {

    static func sanitizedDigits(_ raw: String) -> String {
        raw.filter { $0.isNumber || $0 == "+" }
    }

    static func telURL(phone: String) -> URL? {
        let digits = sanitizedDigits(phone)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    static func whatsAppURL(phone: String, message: String) -> URL? {
        let digits = sanitizedDigits(phone).replacingOccurrences(of: "+", with: "")
        guard !digits.isEmpty else { return nil }
        var components = URLComponents(string: "https://wa.me/\(digits)")
        components?.queryItems = [URLQueryItem(name: "text", value: message)]
        return components?.url
    }

    static func smsURL(phone: String, message: String) -> URL? {
        let digits = sanitizedDigits(phone)
        guard !digits.isEmpty else { return nil }
        var components = URLComponents(string: "sms:\(digits)")
        components?.queryItems = [URLQueryItem(name: "body", value: message)]
        return components?.url
    }
}
