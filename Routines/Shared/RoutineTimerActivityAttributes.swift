//
//  RoutineTimerActivityAttributes.swift
//  Routines
//
//  KEEP IN STEP with RoutinesWidget/RoutineTimerActivityAttributes.swift. The
//  app and the widget extension each need this type, ActivityKit matches the
//  two by name and shape, and the targets can't share one file without a
//  project change — so there are two identical copies.
//

#if os(iOS)
import ActivityKit
import Foundation

/// Describes the Live Activity shown on the Lock Screen while a routine's timer
/// runs.
///
/// The widget draws the countdown itself from `endDate`, so the app only has
/// to update the activity when the timer is paused, resumed or finished — not
/// every second.
struct RoutineTimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the countdown reaches zero, while it's running. `nil` while
        /// paused or finished.
        var endDate: Date?

        /// What was left when the timer was paused, so a paused countdown can
        /// still show its time.
        var remainingSeconds: Double

        var isFinished: Bool
    }

    var routineName: String
    var symbolName: String
    var colorIdentifier: String

    /// The configured length, for the progress bar.
    var totalSeconds: Double
}
#endif
