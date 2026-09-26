//
//  WorkoutLiveActivityController.swift
//  Routines
//

import Foundation
import OSLog

#if os(iOS)
import ActivityKit
#endif

/// Starts and ends the Live Activity that accompanies a running workout.
///
/// Live Activities exist only on iOS and iPadOS, so every call is a no-op
/// elsewhere. Failures are logged rather than surfaced: a workout that can't
/// show a Live Activity is still a perfectly good workout.
@MainActor
final class WorkoutLiveActivityController {
    private let logger = Logger(subsystem: "GuyEinhoren.Routines", category: "LiveActivity")

    #if os(iOS)
    private var activity: Activity<WorkoutActivityAttributes>?
    #endif

    func start(for session: WorkoutSession) {
        #if os(iOS)
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities are disabled for this app.")
            return
        }

        let attributes = WorkoutActivityAttributes(
            listName: session.listName,
            symbolName: session.listSymbolName,
            colorIdentifier: session.listColorIdentifier
        )
        let state = WorkoutActivityAttributes.ContentState(startDate: session.startDate)

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            logger.error("Could not start the workout Live Activity: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    func end() async {
        #if os(iOS)
        guard let activity else { return }
        // Dismiss immediately: the workout is over, so leaving it on the Lock
        // Screen would be stale the moment it ends.
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        #endif
    }
}
