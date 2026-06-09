//
//  BuxCanvasBackgroundPhotoPicker.swift
//  BuxMuse — iPad Bux Canvas background photo picker (isolated native PHPicker).
//

import Photos
import PhotosUI
import UIKit

/// Presents the system photo library without compositing Bux Canvas sheets/shadows underneath (iPad lag fix).
enum BuxCanvasBackgroundPhotoPicker {
    static func present(onPicked: @escaping (UIImage?) -> Void) {
        guard BuxPadIdiom.isPad else {
            onPicked(nil)
            return
        }
        BuxCanvasBackgroundPhotoPickerCoordinator.shared.present(onPicked: onPicked)
    }
}

private final class BuxCanvasPhotoPickerHostViewController: UIViewController {
    var transitionSnapshot: UIView?
}

private final class BuxCanvasBackgroundPhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    static let shared = BuxCanvasBackgroundPhotoPickerCoordinator()

    private enum Transition {
        static let duration: TimeInterval = 0.34
        static let snapshotFadeDelay: TimeInterval = 0.05
        static let closeRevealDuration: TimeInterval = 0.32
    }

    private var onImagePicked: ((UIImage?) -> Void)?
    private var pickerWindow: UIWindow?
    private weak var previousKeyWindow: UIWindow?

    func present(onPicked: @escaping (UIImage?) -> Void) {
        guard let scene = activeWindowScene(),
              let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            onPicked(nil)
            return
        }

        onImagePicked = onPicked
        let hostVC = topViewController(from: rootVC)

        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.routeAfterAuthorization(status, from: hostVC)
                }
            }
        default:
            routeAfterAuthorization(PHPhotoLibrary.authorizationStatus(for: .readWrite), from: hostVC)
        }
    }

    private func routeAfterAuthorization(_ status: PHAuthorizationStatus, from vc: UIViewController) {
        switch status {
        case .authorized:
            openPicker(from: vc)
        case .limited:
            showLimitedAccessPrompt(from: vc)
        case .denied, .restricted:
            showDeniedAlert(from: vc)
        default:
            finish(nil)
        }
    }

    private func openPicker(from vc: UIViewController) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .compatible

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self

        guard let scene = vc.view.window?.windowScene ?? activeWindowScene() else {
            finish(nil)
            return
        }

        presentIsolated(picker, in: scene)
    }

    private func presentIsolated(_ picker: PHPickerViewController, in scene: UIWindowScene) {
        teardownIsolatedWindow(animated: false)

        guard let keyWindow = scene.windows.first(where: \.isKeyWindow) else { return }
        previousKeyWindow = keyWindow

        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.backgroundColor = .clear
        window.windowLevel = .normal + 1

        let host = BuxCanvasPhotoPickerHostViewController()
        host.view.backgroundColor = .clear
        if let snapshot = keyWindow.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = host.view.bounds
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.view.addSubview(snapshot)
            host.transitionSnapshot = snapshot
        } else {
            host.view.backgroundColor = .systemBackground
        }

        window.rootViewController = host
        window.makeKeyAndVisible()
        pickerWindow = window

        picker.modalPresentationStyle = .fullScreen
        picker.modalTransitionStyle = .coverVertical
        host.present(picker, animated: true)

        guard let snapshot = host.transitionSnapshot else { return }
        UIView.animate(
            withDuration: Transition.duration,
            delay: Transition.snapshotFadeDelay,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            snapshot.alpha = 0
        } completion: { _ in
            snapshot.removeFromSuperview()
            host.transitionSnapshot = nil
            host.view.backgroundColor = .systemBackground
        }
    }

    private func teardownIsolatedWindow(animated: Bool, completion: (() -> Void)? = nil) {
        guard let window = pickerWindow else {
            completion?()
            return
        }

        let finish = {
            window.isHidden = true
            window.rootViewController = nil
            window.alpha = 1
            self.pickerWindow = nil
            self.previousKeyWindow?.makeKeyAndVisible()
            self.previousKeyWindow = nil
            completion?()
        }

        guard animated else {
            finish()
            return
        }

        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            window.alpha = 0
        } completion: { _ in
            finish()
        }
    }

    private func finish(_ image: UIImage?) {
        onImagePicked?(image)
        onImagePicked = nil
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive && $0 is UIWindowScene } as? UIWindowScene
    }

    private func topViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return controller
    }

    private func showLimitedAccessPrompt(from vc: UIViewController) {
        let alert = UIAlertController(
            title: BuxLocalizedString.string("Photo Library Access", locale: BuxInterfaceLocale.currentInterfaceLocale),
            message: BuxLocalizedString.string("BuxMuse has access to a limited selection of your photos. You can choose from your currently selected photos, select more photos from your library, or enable full access in Settings.", locale: BuxInterfaceLocale.currentInterfaceLocale),
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: BuxLocalizedString.string("Browse Selected Photos", locale: BuxInterfaceLocale.currentInterfaceLocale),
            style: .default
        ) { _ in
            self.openPicker(from: vc)
        })

        alert.addAction(UIAlertAction(
            title: BuxLocalizedString.string("Select More Photos...", locale: BuxInterfaceLocale.currentInterfaceLocale),
            style: .default
        ) { _ in
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: vc)
        })

        alert.addAction(UIAlertAction(
            title: BuxLocalizedString.string("Open Settings", locale: BuxInterfaceLocale.currentInterfaceLocale),
            style: .default
        ) { _ in
            BusinessCardPhotoLibraryAccess.openSettings()
        })

        alert.addAction(UIAlertAction(
            title: BuxLocalizedString.string("Cancel", locale: BuxInterfaceLocale.currentInterfaceLocale),
            style: .cancel
        ) { _ in
            self.finish(nil)
        })

        if let popover = alert.popoverPresentationController {
            popover.sourceView = vc.view
            popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        vc.present(alert, animated: true)
    }

    private func showDeniedAlert(from vc: UIViewController) {
        let alert = UIAlertController(
            title: BuxLocalizedString.string("Photo Library Access Denied", locale: BuxInterfaceLocale.currentInterfaceLocale),
            message: BuxLocalizedString.string("Please allow photo library access in System Settings to select an image.", locale: BuxInterfaceLocale.currentInterfaceLocale),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: BuxLocalizedString.string("Settings", locale: BuxInterfaceLocale.currentInterfaceLocale),
            style: .default
        ) { _ in
            BusinessCardPhotoLibraryAccess.openSettings()
        })

        alert.addAction(UIAlertAction(
            title: BuxLocalizedString.string("Cancel", locale: BuxInterfaceLocale.currentInterfaceLocale),
            style: .cancel
        ) { _ in
            self.finish(nil)
        })

        vc.present(alert, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let deliver: () -> Void = {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                self.finish(nil)
                return
            }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                let picked = (image as? UIImage)?.normalizedImage()
                DispatchQueue.main.async {
                    self.finish(picked)
                }
            }
        }

        if pickerWindow != nil {
            picker.dismiss(animated: true) {
                self.revealUnderlyingAndTeardown(completion: deliver)
            }
        } else {
            picker.dismiss(animated: true) {
                deliver()
            }
        }
    }

    private func revealUnderlyingAndTeardown(completion: (() -> Void)? = nil) {
        guard let window = pickerWindow,
              let host = window.rootViewController else {
            teardownIsolatedWindow(animated: false, completion: completion)
            return
        }

        if let underlying = previousKeyWindow,
           let snapshot = underlying.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = host.view.bounds
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            snapshot.alpha = 0
            host.view.addSubview(snapshot)

            UIView.animate(
                withDuration: Transition.closeRevealDuration,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState]
            ) {
                snapshot.alpha = 1
            } completion: { _ in
                self.teardownIsolatedWindow(animated: false, completion: completion)
            }
        } else {
            teardownIsolatedWindow(animated: true, completion: completion)
        }
    }
}
