//
//  ImageData.swift
//  Routines
//

import SwiftUI

extension Image {
    /// Builds an image from photo data the person picked, on whichever platform
    /// the app is running on.
    ///
    /// Returns `nil` when the data isn't decodable, which lets callers fall back
    /// to the routine's symbol rather than showing a broken placeholder.
    init?(data: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #else
        return nil
        #endif
    }
}
