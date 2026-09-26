//
//  WorkoutActivityAttributes.swift
//  Routines
//
//  Shared between the app and the Live Activity widget. Both targets must
//  compile this file — the attributes type has to be the same type on each
//  side of ActivityKit.
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
