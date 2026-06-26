//
//  ConnectivityBrain.swift
//  BuxMuse
//
//  Local path monitoring for offline-aware UX (merchant icons, toasts).
//

import Foundation
import Network
import Combine

public enum ConnectivityToastStyle: Equatable, Sendable {
    case offline
    case online
    case informational
}

public struct ConnectivityToast: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let message: String
    public let style: ConnectivityToastStyle

    public init(id: UUID = UUID(), message: String, style: ConnectivityToastStyle) {
        self.id = id
        self.message = message
        self.style = style
    }
}

@MainActor
public final class ConnectivityBrain: ObservableObject {
    public static let shared = ConnectivityBrain()

    @Published public private(set) var isOnline: Bool = true
    @Published public private(set) var activeToast: ConnectivityToast?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.buxmuse.connectivity", qos: .utility)
    private var didShowOfflineToastThisSession = false
    private var wasOffline = false

    private init() {
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor in
                ConnectivityBrain.shared.apply(online: online)
            }
        }
        monitor.start(queue: queue)
    }

    /// Gates merchant icon / favicon network fetches (offline + Data Guard).
    public var shouldFetchMerchantIcons: Bool {
        isOnline && !SettingsStore.shared.dataGuardModeEnabled
    }

    public func dismissToast() {
        activeToast = nil
    }

    private func apply(online: Bool) {
        isOnline = online
        let locale = BuxInterfaceLocale.currentInterfaceLocale

        if !online {
            wasOffline = true
            guard !didShowOfflineToastThisSession else { return }
            didShowOfflineToastThisSession = true
            activeToast = ConnectivityToast(
                message: BuxLocalizedString.string(
                    "Offline — BuxMuse still works locally",
                    locale: locale
                ),
                style: .offline
            )
            scheduleToastDismiss()
            return
        }

        if wasOffline {
            wasOffline = false
            activeToast = ConnectivityToast(
                message: BuxLocalizedString.string("Back online", locale: locale),
                style: .online
            )
            scheduleToastDismiss()
        }
    }

    private func scheduleToastDismiss() {
        let toastId = activeToast?.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if activeToast?.id == toastId {
                activeToast = nil
            }
        }
    }
}
