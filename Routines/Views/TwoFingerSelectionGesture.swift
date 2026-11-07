//
//  TwoFingerSelectionGesture.swift
//  Routines
//

#if os(iOS)
import SwiftUI
import UIKit

/// A two-finger drag down a list, reported as a location in the global
/// coordinate space — the gesture Reminders and Mail use to select a run of
/// rows at once in edit mode.
///
/// SwiftUI has no multi-touch drag of its own, so this wraps a pan recognizer
/// that needs exactly two touches. It recognizes alongside the list's scroll
/// view, and once it begins it cancels that scroll, so the fingers select
/// rows rather than move the list under them.
struct TwoFingerSelectionGesture: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 2
        recognizer.maximumNumberOfTouches = 2
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let location = context.converter.location(in: .global)
        switch recognizer.state {
        case .began:
            context.coordinator.stopScrolling()
            onBegan(location)
        case .changed:
            onChanged(location)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// The pan of the scroll view the list lives in, found when it asks to
        /// recognize alongside this gesture.
        private weak var scrollPan: UIPanGestureRecognizer?

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            if let scrollView = otherGestureRecognizer.view as? UIScrollView,
               otherGestureRecognizer === scrollView.panGestureRecognizer {
                scrollPan = scrollView.panGestureRecognizer
            }
            return true
        }

        /// Cancels a scroll the same two fingers started, by switching the
        /// scroll view's pan off and straight back on.
        func stopScrolling() {
            guard let scrollPan, scrollPan.isEnabled else { return }
            scrollPan.isEnabled = false
            scrollPan.isEnabled = true
        }
    }
}
#endif
