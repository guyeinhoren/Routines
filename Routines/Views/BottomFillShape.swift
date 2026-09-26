//
//  BottomFillShape.swift
//  Routines
//

import SwiftUI

/// A rectangle anchored to the bottom of its bounds, covering `fraction` of the
/// available height.
///
/// This is a `Shape` rather than a resized rectangle or a stop-based gradient
/// because only a shape lets SwiftUI interpolate the fraction itself. A gradient
/// with hard colour stops isn't animatable, so the fill would jump straight to
/// its new height instead of rising into it.
struct BottomFillShape: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // A spring overshoots, so clamp rather than letting the fill escape the
        // square at either end of the animation.
        let clamped = min(1, max(0, fraction))
        guard clamped > 0 else { return Path() }

        let height = rect.height * clamped
        return Path(
            CGRect(x: rect.minX, y: rect.maxY - height, width: rect.width, height: height)
        )
    }
}
