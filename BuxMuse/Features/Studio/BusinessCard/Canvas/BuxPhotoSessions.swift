//
//  BuxPhotoSessions.swift
//  BuxMuse
//

import UIKit

enum BuxPhotoStudioTarget: Hashable, Identifiable {
    case profilePhoto
    case logo
    case backgroundPhoto
    case canvasLayer(UUID)

    var id: String {
        switch self {
        case .profilePhoto: return "profile"
        case .logo: return "logo"
        case .backgroundPhoto: return "background"
        case .canvasLayer(let id): return "layer-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .profilePhoto: return "Your photo"
        case .logo: return "Business logo"
        case .backgroundPhoto: return "Background"
        case .canvasLayer: return "Image layer"
        }
    }

    var icon: String {
        switch self {
        case .profilePhoto: return "person.crop.circle"
        case .logo: return "briefcase.fill"
        case .backgroundPhoto: return "photo.fill.on.rectangle.fill"
        case .canvasLayer: return "photo"
        }
    }

    var supportsFrameMask: Bool {
        switch self {
        case .backgroundPhoto: return false
        default: return true
        }
    }
}

struct BuxPhotoStudioResult {
    let target: BuxPhotoStudioTarget
    let image: UIImage
    let transform: ProBusinessCardPhotoTransform
    let adjustments: ProBusinessCardPhotoAdjustments
    let mask: CardImageMask
}

struct BuxPhotoStudioSession: Identifiable {
    let id = UUID()
    let targets: [BuxPhotoStudioTarget]
    var selectedTarget: BuxPhotoStudioTarget
    let image: UIImage
    let layerID: UUID?
    let initialTransform: ProBusinessCardPhotoTransform
    let initialAdjustments: ProBusinessCardPhotoAdjustments
    let initialMask: CardImageMask

    init(
        targets: [BuxPhotoStudioTarget],
        selectedTarget: BuxPhotoStudioTarget,
        image: UIImage,
        layerID: UUID? = nil,
        initialTransform: ProBusinessCardPhotoTransform = ProBusinessCardPhotoTransform(),
        initialAdjustments: ProBusinessCardPhotoAdjustments = ProBusinessCardPhotoAdjustments(),
        initialMask: CardImageMask = .circle
    ) {
        self.targets = targets
        self.selectedTarget = selectedTarget
        self.image = image
        self.layerID = layerID
        self.initialTransform = initialTransform
        self.initialAdjustments = initialAdjustments
        self.initialMask = initialMask
    }
}

struct BuxPhotoLabSession: Identifiable {
    let id = UUID()
    let image: UIImage
    let layerID: UUID
}

struct BuxPhotoEditorSession: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct BuxBackgroundPhotoFlow: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct BuxFocalSession: Identifiable {
    let id = UUID()
    let target: BuxFocalEditorTarget
    let image: UIImage
    let title: String
    let cropIsCircle: Bool
    var viewportSize: CGSize? = nil
    var viewportCornerRadius: CGFloat = 12
}
