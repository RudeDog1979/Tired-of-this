//
//  BuxNativeTabBarSuppressor.swift
//  BuxMuse
//
//  Hides the system UITabBar and removes its layout / safe-area slot.
//

import SwiftUI
import UIKit

struct BuxNativeTabBarSuppressor: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SuppressorViewController {
        SuppressorViewController()
    }

    func updateUIViewController(_ uiViewController: SuppressorViewController, context: Context) {
        uiViewController.suppress()
    }

    final class SuppressorViewController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            suppress()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            suppress()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            suppress()
        }

        func suppress() {
            guard let controller = resolveTabBarController() else { return }
            let tabBar = controller.tabBar

            tabBar.isHidden = true
            tabBar.alpha = 0
            tabBar.isUserInteractionEnabled = false
            tabBar.isTranslucent = true
            tabBar.subviews.forEach { $0.isHidden = true }

            var frame = tabBar.frame
            frame.size.height = 0
            frame.origin.y = controller.view.bounds.maxY
            tabBar.frame = frame

            controller.viewControllers?.forEach { viewController in
                viewController.additionalSafeAreaInsets.bottom = 0
                viewController.view.backgroundColor = .clear
            }

            // Prevent UIKit from reserving bottom space for a hidden tab bar.
            if #available(iOS 18.0, *) {
                controller.setTabBarHidden(true, animated: false)
            }
        }

        private func resolveTabBarController() -> UITabBarController? {
            if let tabBarController {
                return tabBarController
            }
            return Self.findTabBarController(from: view.window?.rootViewController)
        }

        private static func findTabBarController(from viewController: UIViewController?) -> UITabBarController? {
            if let tabBarController = viewController as? UITabBarController {
                return tabBarController
            }
            for child in viewController?.children ?? [] {
                if let found = findTabBarController(from: child) {
                    return found
                }
            }
            return nil
        }
    }
}
