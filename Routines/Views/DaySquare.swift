//
//  DaySquare.swift
//  Routines
//

import SwiftUI

/// One day of a routine's progress.
///
/// The square fills from the bottom in proportion to how much of the day's
/// target has been performed, so a routine with several repetitions a day shows
/// partial progress rather than only done or not done. Filling vertically also
/// means the indicator reads the same way in right-to-left layouts.
struct DaySquare: View {
    let progress: Double
    let color: Color
    let isToday: Bool
    let isFuture: Bool
    let side: CGFloat

    /// Bumped each time a repetition is recorded, which makes today's square
    /// pop. Only today's square reacts, so the other six stay still.
    let pulseTrigger: Int

    private var cornerRadius: CGFloat { side * 0.3 }

    /// A lighter neutral than the system's `quaternary` fill, which reads too
    /// heavy against the plain list background.
    private var emptyFill: Color {
        .primary.opacity(isFuture ? 0.04 : 0.08)
    }

    var body: some View {
        if isToday {
            square
                .keyframeAnimator(initialValue: 1.0, trigger: pulseTrigger) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.24, duration: 0.16, spring: .bouncy)
                        SpringKeyframe(1.0, duration: 0.36, spring: .bouncy)
                    }
                }
        } else {
            square
        }
    }

    private var square: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(emptyFill)
            .overlay {
                BottomFillShape(fraction: progress)
                    .fill(color)
                    .animation(.bouncy(duration: 0.45, extraBounce: 0.25), value: progress)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                // A ring marks the day a tap on the row applies to.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isToday ? color : .clear, lineWidth: 1.5)
            }
            .frame(width: side, height: side)
    }
}
