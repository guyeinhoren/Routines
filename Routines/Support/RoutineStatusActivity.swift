//
//  RoutineStatusActivity.swift
//  Routines
//

#if os(iOS)
import ActivityKit
import Foundation
import OSLog
import SwiftData

/// The Live Activity that follows the routine the person last tapped.
///
/// One at a time: tapping another routine's squares moves it there. It shows
/// that routine's week, and today's square in it works like the one in the
/// list. Can be turned off in Settings.
@MainActor
enum RoutineStatusActivity {
    private static let logger = Logger(subsystem: "GuyEinhoren.Routines", category: "StatusActivity")

    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.showRoutineLiveActivity)
    }

    /// Makes `routine` the one the Live Activity follows, shown for the list it
    /// was tapped in.
    static func show(_ routine: Routine, destination: ListDestination) {
        guard isEnabled else {
            end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let routineID = encodedID(of: routine)
        else { return }

        let content = ActivityContent(state: state(for: routine), staleDate: nil)

        // The same routine only needs its squares redrawn.
        if let existing = Activity<RoutineStatusActivityAttributes>.activities.first(where: {
            $0.attributes.routineID == routineID && $0.attributes.destinationURL == destination.url
        }) {
            Task { await existing.update(content) }
            return
        }

        end()

        let attributes = RoutineStatusActivityAttributes(
            routineID: routineID,
            routineName: routine.name,
            symbolName: routine.symbolName,
            colorIdentifier: routine.colorIdentifier,
            destinationURL: destination.url
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content)
        } catch {
            logger.error("Could not start the routine Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Redraws the activity if it's following `routine`.
    static func refresh(_ routine: Routine) {
        guard let routineID = encodedID(of: routine) else { return }
        let content = ActivityContent(state: state(for: routine), staleDate: nil)
        for activity in Activity<RoutineStatusActivityAttributes>.activities where activity.attributes.routineID == routineID {
            Task { await activity.update(content) }
        }
    }

    /// Takes the activity off the Lock Screen.
    static func end() {
        for activity in Activity<RoutineStatusActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Ends the activity if the person has switched it off in Settings.
    static func endIfDisabled() {
        if !isEnabled { end() }
    }

    /// Today's square was tapped in the Live Activity.
    static func advance(routineID: String) {
        guard let data = Data(base64Encoded: routineID),
              let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        else { return }

        let context = RoutineContainer.shared.mainContext
        guard let routine = context.model(for: id) as? Routine else { return }

        RoutineStore.advance(routine, on: .today, in: context)
        try? context.save()
        refresh(routine)
    }

    // MARK: - Content

    private static func encodedID(of routine: Routine) -> String? {
        try? JSONEncoder().encode(routine.persistentModelID).base64EncodedString()
    }

    private static func state(for routine: Routine) -> RoutineStatusActivityAttributes.ContentState {
        let today = DayKey.today
        let week = WeekPlanner.week(containing: Date()).map { DayKey($0) }
        let counts = routine.completionCounts(from: week.first ?? today, through: week.last ?? today)
        let done = counts[today.value] ?? 0

        return .init(
            weekProgress: week.map { routine.progress(forCount: counts[$0.value] ?? 0) },
            todayIndex: week.firstIndex(of: today) ?? -1,
            doneToday: done,
            target: routine.dailyTarget,
            valueText: routine.valueDescription()
        )
    }
}
#endif
