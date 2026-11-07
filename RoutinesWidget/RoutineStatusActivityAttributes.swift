//
//  RoutineStatusActivityAttributes.swift
//  RoutinesWidget
//
//  KEEP IN STEP with Routines/Shared/RoutineStatusActivityAttributes.swift. The
//  app and the widget extension each need this type, ActivityKit matches the
//  two by name and shape, and the targets can't share one file without a
//  project change — so there are two identical copies.
//

#if os(iOS)
import ActivityKit
import Foundation

/// Describes the Live Activity that follows the routine the person last tapped:
/// its week of squares, with today's one a button.
nonisolated struct RoutineStatusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// How full each day's square is, from 0 to 1, in the order the week
        /// is laid out on the main screen.
        var weekProgress: [Double]

        /// Which of `weekProgress` is today, or -1 if none is.
        var todayIndex: Int

        /// Repetitions done today and the day's target, for the caption.
        var doneToday: Int
        var target: Int

        /// The routine's number with its unit — "30 kg" — if it tracks one.
        var valueText: String?
    }

    /// The routine, encoded for `AdvanceRoutineIntent` to find it again.
    var routineID: String
    var routineName: String
    var symbolName: String
    var colorIdentifier: String

    /// Where a tap on anything but today's square goes: the list the routine
    /// was tapped in.
    var destinationURL: URL?
}
#endif
