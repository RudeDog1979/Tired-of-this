//
//  StudioTimerDeepLink.swift
//  BuxMuse
//
//  Opens Log Time when the user taps the Studio timer Live Activity.
//

import Foundation

enum StudioTimerDeepLink {
    /// Register `buxmuse` in CFBundleURLTypes (project BuxMuse-Info.plist).
    static let logTimeURL = URL(string: "buxmuse://studio/log-time")!

    static func matches(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "buxmuse" else { return false }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if host == "studio" {
            return path.isEmpty || path == "log-time"
        }
        return host == "log-time"
    }
}
