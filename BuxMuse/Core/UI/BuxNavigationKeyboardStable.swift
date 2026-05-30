//
//  BuxNavigationKeyboardStable.swift
//  BuxMuse
//
//  Prevents NavigationStack large/inline bars from shifting up when the keyboard appears.
//  Apply on pushed Studio lists and settings forms — never on root tabs or sheets.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI modifier

struct BuxNavigationKeyboardStableModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(BuxNavigationKeyboardAnchorRepresentable())
    }
}

extension View {
    /// Keeps the navigation bar visually pinned while the keyboard is visible.
    func buxStableNavigationBarWithKeyboard() -> some View {
        modifier(BuxNavigationKeyboardStableModifier())
    }
}

// MARK: - UIKit anchor (local nav controller only — no window-root walks)

private struct BuxNavigationKeyboardAnchorRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AnchorViewController {
        AnchorViewController()
    }

    func updateUIViewController(_ uiViewController: AnchorViewController, context: Context) {
        uiViewController.applyFix()
    }

    final class AnchorViewController: UIViewController {
        private var didApply = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            didApply = false
            applyFix()
        }

        func applyFix() {
            guard !didApply else { return }
            guard let navigationController = findLocalNavigationController() else { return }
            didApply = true
            if #available(iOS 17.0, *) {
                navigationController.view.keyboardLayoutGuide.followsUndockedKeyboard = true
            }
            navigationController.navigationBar.isTranslucent = true
        }

        /// Only the enclosing NavigationStack — never the tab root underneath a sheet.
        private func findLocalNavigationController() -> UINavigationController? {
            sequence(first: parent, next: { $0?.parent })
                .compactMap { $0 as? UINavigationController }
                .first
        }
    }
}
