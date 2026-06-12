//
//  BusinessCardCIFilterPipeline.swift
//  BuxMuse
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BusinessCardCIFilterPipeline {
    static let presets: [(name: String, ciName: String)] = [
        ("Original", "none"),
        ("Chrome", "CIPhotoEffectChrome"),
        ("Fade", "CIPhotoEffectFade"),
        ("Instant", "CIPhotoEffectInstant"),
        ("Noir", "CIPhotoEffectNoir"),
        ("Transfer", "CIPhotoEffectTransfer"),
        ("Mono", "CIPhotoEffectMono"),
        ("Process", "CIPhotoEffectProcess"),
    ]

    nonisolated static func apply(
        to source: UIImage,
        presetFilterName: String,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        sharpness: Double,
        exposure: Double,
        brilliance: Double,
        in context: CIContext
    ) -> UIImage? {
        guard var ciImage = CIImage(image: source) else { return nil }

        if presetFilterName != "none", let preset = CIFilter(name: presetFilterName) {
            preset.setValue(ciImage, forKey: kCIInputImageKey)
            if let out = preset.outputImage { ciImage = out }
        }

        if exposure != 0 {
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = ciImage
            exposureFilter.ev = Float(exposure)
            if let out = exposureFilter.outputImage { ciImage = out }
        }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.brightness = Float(brightness)
        colorControls.contrast = Float(contrast)
        colorControls.saturation = Float(saturation)
        guard let colorOut = colorControls.outputImage else { return nil }
        ciImage = colorOut

        if brilliance != 0 {
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = ciImage
            highlightShadow.highlightAmount = Float(1 - brilliance * 0.45)
            highlightShadow.shadowAmount = Float(brilliance * 0.85)
            if let out = highlightShadow.outputImage { ciImage = out }
        }

        if sharpness > 0 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = ciImage
            sharpen.sharpness = Float(sharpness)
            if let sharpOut = sharpen.outputImage { ciImage = sharpOut }
        }

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: source.scale, orientation: source.imageOrientation)
    }
}

enum BusinessCardPhotoLabEngine {
    private nonisolated static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated static func render(source: UIImage, adjustments: ProBusinessCardPhotoAdjustments) -> UIImage? {
        BusinessCardCIFilterPipeline.apply(
            to: source,
            presetFilterName: adjustments.filterName,
            brightness: adjustments.brightness,
            contrast: adjustments.contrast,
            saturation: adjustments.saturation,
            sharpness: adjustments.sharpness,
            exposure: adjustments.exposure,
            brilliance: adjustments.brilliance,
            in: ciContext
        )
    }
}
