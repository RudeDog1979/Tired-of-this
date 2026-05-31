//
//  ProBusinessCardLayoutEngine.swift
//  BuxMuse
//
//  Precise safe-zone geometry for photo placement and content flow.
//

import CoreGraphics
import Foundation

struct ProBusinessCardLayoutEngine: Sendable {
    let cardSize: CGSize
    let safeInset: CGFloat
    let photoScale: ProBusinessCardPhotoScale
    let placement: ProBusinessCardPhotoPlacement
    let showsPhoto: Bool

    private static let gutter: CGFloat = 8

    var safeRect: CGRect {
        CGRect(
            x: safeInset,
            y: safeInset,
            width: max(0, cardSize.width - safeInset * 2),
            height: max(0, cardSize.height - safeInset * 2)
        )
    }

    var isStrip: Bool { placement.isStrip }

    func photoDiameter() -> CGFloat {
        guard showsPhoto, photoScale != .off else { return 0 }
        return min(cardSize.width, cardSize.height) * photoScale.pointRatio
    }

    func stripThickness() -> CGFloat {
        guard showsPhoto, photoScale != .off else { return 0 }
        let safe = safeRect
        switch photoScale {
        case .off: return 0
        case .corner: return min(safe.width, safe.height) * 0.28
        case .medium: return min(safe.width, safe.height) * 0.36
        case .hero: return min(safe.width, safe.height) * 0.46
        }
    }

    /// Exact photo region in card coordinates.
    func photoFrame() -> CGRect {
        let safe = safeRect
        let d = photoDiameter()
        guard d > 0 else { return .zero }

        if isStrip {
            let t = stripThickness()
            switch placement {
            case .leftBand:
                return CGRect(x: safe.minX, y: safe.minY, width: t, height: safe.height)
            case .rightBand:
                return CGRect(x: safe.maxX - t, y: safe.minY, width: t, height: safe.height)
            case .topBand:
                return CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: t)
            case .bottomBand:
                return CGRect(x: safe.minX, y: safe.maxY - t, width: safe.width, height: t)
            default:
                return .zero
            }
        }

        let origin = anchorOrigin(diameter: d, in: safe)
        return CGRect(x: origin.x, y: origin.y, width: d, height: d)
    }

    /// Content area that never overlaps the photo region.
    func contentRect() -> CGRect {
        let safe = safeRect
        let photo = photoFrame()
        guard photo != .zero else { return safe }

        if isStrip {
            switch placement {
            case .leftBand:
                return CGRect(
                    x: photo.maxX + Self.gutter,
                    y: safe.minY,
                    width: max(0, safe.maxX - photo.maxX - Self.gutter),
                    height: safe.height
                )
            case .rightBand:
                return CGRect(
                    x: safe.minX,
                    y: safe.minY,
                    width: max(0, photo.minX - safe.minX - Self.gutter),
                    height: safe.height
                )
            case .topBand:
                return CGRect(
                    x: safe.minX,
                    y: photo.maxY + Self.gutter,
                    width: safe.width,
                    height: max(0, safe.maxY - photo.maxY - Self.gutter)
                )
            case .bottomBand:
                return CGRect(
                    x: safe.minX,
                    y: safe.minY,
                    width: safe.width,
                    height: max(0, photo.minY - safe.minY - Self.gutter)
                )
            default:
                return safe
            }
        }

        var rect = safe
        switch placement {
        case .topLeft, .top, .topRight:
            rect.origin.y = max(rect.origin.y, photo.maxY + Self.gutter * 0.5)
            rect.size.height = max(0, safe.maxY - rect.origin.y)
        case .bottomLeft, .bottom, .bottomRight:
            rect.size.height = max(0, photo.minY - safe.minY - Self.gutter * 0.5)
        case .left:
            rect.origin.x = max(rect.origin.x, photo.maxX + Self.gutter)
            rect.size.width = max(0, safe.maxX - rect.origin.x)
        case .right:
            rect.size.width = max(0, photo.minX - safe.minX - Self.gutter)
        case .center:
            break
        default:
            break
        }

        if placement.isLeadingCorner || placement == .left {
            rect.size.width = max(0, rect.width - photo.width * 0.15)
        }
        if placement.isTrailingCorner || placement == .right {
            let trim = photo.width * 0.15
            rect.size.width = max(0, rect.width - trim)
            if placement.isTrailingCorner {
                rect.origin.x = safe.minX
            }
        }
        return rect
    }

    private func anchorOrigin(diameter d: CGFloat, in safe: CGRect) -> CGPoint {
        switch placement {
        case .topLeft:
            return CGPoint(x: safe.minX, y: safe.minY)
        case .top:
            return CGPoint(x: safe.midX - d / 2, y: safe.minY)
        case .topRight:
            return CGPoint(x: safe.maxX - d, y: safe.minY)
        case .left:
            return CGPoint(x: safe.minX, y: safe.midY - d / 2)
        case .center:
            return CGPoint(x: safe.midX - d / 2, y: safe.midY - d / 2)
        case .right:
            return CGPoint(x: safe.maxX - d, y: safe.midY - d / 2)
        case .bottomLeft:
            return CGPoint(x: safe.minX, y: safe.maxY - d)
        case .bottom:
            return CGPoint(x: safe.midX - d / 2, y: safe.maxY - d)
        case .bottomRight:
            return CGPoint(x: safe.maxX - d, y: safe.maxY - d)
        default:
            return CGPoint(x: safe.maxX - d, y: safe.maxY - d)
        }
    }
}

extension ProBusinessCardPhotoPlacement {
    var isStrip: Bool {
        switch self {
        case .leftBand, .topBand, .rightBand, .bottomBand: return true
        default: return false
        }
    }

    var isLeadingCorner: Bool {
        self == .topLeft || self == .bottomLeft
    }

    var isTrailingCorner: Bool {
        self == .topRight || self == .bottomRight
    }

    /// Grid positions shown in the 3×3 picker (excludes strips).
    static var gridPositions: [ProBusinessCardPhotoPlacement] {
        [.topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight]
    }

    static var stripPositions: [ProBusinessCardPhotoPlacement] {
        [.leftBand, .topBand, .rightBand, .bottomBand]
    }

    var gridIcon: String {
        switch self {
        case .topLeft: return "arrow.up.left"
        case .top: return "arrow.up"
        case .topRight: return "arrow.up.right"
        case .left: return "arrow.left"
        case .center: return "circle.fill"
        case .right: return "arrow.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottom: return "arrow.down"
        case .bottomRight: return "arrow.down.right"
        case .leftBand: return "rectangle.leadinghalf.inset.filled"
        case .topBand: return "rectangle.tophalf.inset.filled"
        case .rightBand: return "rectangle.trailinghalf.inset.filled"
        case .bottomBand: return "rectangle.bottomhalf.inset.filled"
        }
    }
}
