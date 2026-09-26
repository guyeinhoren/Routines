//
//  ImageDownscaling.swift
//  Routines
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Data {
    /// Re-encodes image data as a JPEG no larger than `maxDimension` on its
    /// longest side.
    ///
    /// A routine's photo is only ever drawn as a small badge, so keeping the
    /// original capture would waste storage and push megabytes through CloudKit
    /// on every sync. Returns `nil` when the data isn't a decodable image.
    func downscaledImageData(maxDimension: CGFloat = 512, compressionQuality: Double = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honours the capture orientation so portrait photos aren't sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
