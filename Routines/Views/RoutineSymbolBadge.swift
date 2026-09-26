//
//  RoutineSymbolBadge.swift
//  Routines
//

import SwiftUI

/// A routine's symbol on a tint of its colour.
///
/// The photo deliberately doesn't appear here: it belongs at the head of the
/// description, wide, where it can actually be seen. A photo squeezed into a
/// badge this size reads as noise and loses the symbol's clarity.
struct RoutineSymbolBadge: View {
    let routine: Routine
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            routine.color.opacity(0.18)

            Image(systemName: routine.symbolName)
                .font(.system(size: size * 0.5))
                .foregroundStyle(routine.color)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A routine's photo as a wide banner, for the head of its description.
struct RoutinePhotoBanner: View {
    let imageData: Data
    var height: CGFloat = 170

    var body: some View {
        if let image = Image(data: imageData) {
            image
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .frame(maxWidth: .infinity)
                // Clipping after both frames keeps the fill from bleeding past
                // the rounded corners.
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(Text("Routine photo", comment: "VoiceOver label for the routine's photo"))
        }
    }
}
