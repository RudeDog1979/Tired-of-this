//
//  BuxPadAuxiliaryWindowChrome.swift
//  BuxMuse — Titles + first-open hints for Stage Manager auxiliary windows.
//

import SwiftUI
import UIKit

enum BuxPadAuxiliaryWindowKind: String {
    case expense
    case studio

    var title: String {
        switch self {
        case .expense: return "BuxMuse Expenses"
        case .studio: return "BuxMuse Studio"
        }
    }

    var hintMessage: String {
        switch self {
        case .expense:
            return "This window stays on Expenses while you work in the main BuxMuse window."
        case .studio:
            return "This window stays on Studio while you use Home or Expenses in the main window."
        }
    }

    private var hintSeenKey: String { "buxPad.auxiliaryHintSeen.\(rawValue)" }

    var shouldShowHint: Bool {
        guard BuxPadIdiom.isPad else { return false }
        return !UserDefaults.standard.bool(forKey: hintSeenKey)
    }

    func markHintSeen() {
        UserDefaults.standard.set(true, forKey: hintSeenKey)
    }
}

extension View {
    func buxPadAuxiliaryWindowChrome(kind: BuxPadAuxiliaryWindowKind) -> some View {
        modifier(BuxPadAuxiliaryWindowChromeModifier(kind: kind))
    }
}

private struct BuxPadAuxiliaryWindowChromeModifier: ViewModifier {
    let kind: BuxPadAuxiliaryWindowKind

    @State private var showHint: Bool

    init(kind: BuxPadAuxiliaryWindowKind) {
        self.kind = kind
        _showHint = State(initialValue: kind.shouldShowHint)
    }

    func body(content: Content) -> some View {
        content
            .background {
                BuxPadWindowTitleSetter(title: kind.title)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showHint {
                    BuxPadAuxiliaryWindowHintBanner(
                        message: kind.hintMessage,
                        onDismiss: {
                            kind.markHintSeen()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showHint = false
                            }
                        }
                    )
                }
            }
    }
}

private struct BuxPadAuxiliaryWindowHintBanner: View {
    let message: String
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                .padding(.top, 2)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(BuxCatalogLabel.string("Dismiss", locale: BuxInterfaceLocale.currentInterfaceLocale))
        }
        .padding(.horizontal, BuxPadLayout.marginRegular)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct BuxPadWindowTitleSetter: UIViewControllerRepresentable {
    let title: String

    func makeUIViewController(context: Context) -> Controller {
        Controller(title: title)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.title = title
        uiViewController.applyWindowTitle()
    }

    final class Controller: UIViewController {
        init(title: String) {
            super.init(nibName: nil, bundle: nil)
            self.title = title
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyWindowTitle()
        }

        func applyWindowTitle() {
            guard BuxPadIdiom.isPad, let title else { return }
            if let window = view.window {
                window.rootViewController?.title = title
            }
        }
    }
}
