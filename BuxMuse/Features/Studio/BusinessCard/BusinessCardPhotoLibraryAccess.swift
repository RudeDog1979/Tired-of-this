//
//  BusinessCardPhotoLibraryAccess.swift
//  BuxMuse
//

import Photos
import SwiftUI

enum BusinessCardPhotoLibraryAccess {

    enum Status: Equatable {
        case notDetermined
        case limited
        case authorized
        case denied
        case restricted

        var label: String {
            localizedLabel(locale: BuxInterfaceLocale.currentInterfaceLocale)
        }

        func localizedLabel(locale: Locale) -> String {
            switch self {
            case .notDetermined:
                return BuxLocalizedString.string("Not asked yet", locale: locale)
            case .limited:
                return BuxLocalizedString.string("Limited access", locale: locale)
            case .authorized:
                return BuxLocalizedString.string("Full access", locale: locale)
            case .denied:
                return BuxLocalizedString.string("Denied", locale: locale)
            case .restricted:
                return BuxLocalizedString.string("Restricted", locale: locale)
            }
        }
    }

    static func currentStatus() -> Status {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notDetermined
        case .limited: return .limited
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static func requestAccess() async -> Status {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .notDetermined: return .notDetermined
        case .limited: return .limited
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct BusinessCardPhotoAccessBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var status = BusinessCardPhotoLibraryAccess.currentStatus()

    var body: some View {
        if status == .denied || status == .restricted {
            BuxThemedCardForm {
                BuxFormSection(title: "Photo access") {
                    BuxCatalogDynamicText(key: "BuxMuse needs photo access to set card backgrounds and portraits. You can allow full or limited access in Settings.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Button("Open Settings") {
                        BusinessCardPhotoLibraryAccess.openSettings()
                    }
                    .buxFormFieldPadding()
                }
            }
        } else if status == .notDetermined {
            BuxThemedCardForm {
                BuxFormSection(title: "Photo access") {
                    BuxCatalogDynamicText(key: "Allow photo access to pick backgrounds and portraits for your card.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Button("Allow photos") {
                        Task {
                            status = await BusinessCardPhotoLibraryAccess.requestAccess()
                        }
                    }
                    .buxFormFieldPadding()
                }
            }
        } else {
            HStack {
                Image(systemName: status == .limited ? "photo.badge.checkmark" : "photo.on.rectangle.angled")
                    .foregroundColor(themeManager.current.accentColor)
                Text(
                    BuxLocalizedString.format(
                        "Photos: %@",
                        locale: BuxInterfaceLocale.currentInterfaceLocale,
                        status.label
                    )
                )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Settings") { BusinessCardPhotoLibraryAccess.openSettings() }
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.vertical, 4)
        }
    }
}
