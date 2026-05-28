//
//  BuxNavigationKeyboardStable.swift
//  BuxMuse
//
//  Prevents NavigationStack large/inline bars from shifting up when the keyboard appears.
//  Apply on pushed Studio lists, settings forms, and modal trip sheets.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI modifier

struct BuxNavigationKeyboardStableModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .background(BuxNavigationKeyboardAnchorRepresentable())
    }
}

extension View {
    /// Keeps the navigation bar visually pinned while the keyboard is visible.
    func buxStableNavigationBarWithKeyboard() -> some View {
        modifier(BuxNavigationKeyboardStableModifier())
    }
}

// MARK: - UIKit anchor (keyboard layout guide should not compress the nav chrome)

private struct BuxNavigationKeyboardAnchorRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AnchorViewController {
        AnchorViewController()
    }

    func updateUIViewController(_ uiViewController: AnchorViewController, context: Context) {
        uiViewController.applyFix()
    }

    final class AnchorViewController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyFix()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyFix()
        }

        func applyFix() {
            guard let navigationController = findNavigationController() else { return }
            if #available(iOS 17.0, *) {
                navigationController.view.keyboardLayoutGuide.followsUndockedKeyboard = true
            }
            navigationController.navigationBar.isTranslucent = true
        }

        private func findNavigationController() -> UINavigationController? {
            sequence(first: parent, next: { $0?.parent })
                .compactMap { $0 as? UINavigationController }
                .first
                ?? view.window?.buxNearestNavigationController()
        }
    }
}

private extension UIWindow {
    func buxNearestNavigationController() -> UINavigationController? {
        guard let root = rootViewController else { return nil }
        return Self.buxFindNavigationController(in: root)
    }

    private static func buxFindNavigationController(in controller: UIViewController) -> UINavigationController? {
        if let nav = controller as? UINavigationController { return nav }
        for child in controller.children {
            if let found = buxFindNavigationController(in: child) { return found }
        }
        if let presented = controller.presentedViewController {
            return buxFindNavigationController(in: presented)
        }
        return nil
    }
}
