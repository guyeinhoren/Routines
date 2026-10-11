//
//  WorkoutActivityAttributes.swift
//  RoutinesWidget
//
//  KEEP IN STEP with Routines/Shared/WorkoutActivityAttributes.swift. The app
//  and the widget extension each need this type, ActivityKit matches the two
//  by name and shape, and the targets can't share one file without a project
//  change — so there are two identical copies.
//

#if os(iOS)
import ActivityKit
import Foundation

/// Describes the Live Activity shown while a workout is running.
///
/// The fixed attributes carry the list's identity; the content state carries
/// only the start date, because the widget can run its own timer from that and
/// so needs no updates pushed to it while the workout continues.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
    }

    var listName: String
    var symbolName: String
    var colorIdentifier: String
}
#endif
