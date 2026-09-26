//
//  WorkoutController.swift
//  Routines
//

import Foundation
import SwiftData

/// Owns the workout that is currently underway.
///
/// A workout is a stretch of time spent on the routines of one list. The
/// session lives in the store rather than only in memory, so quitting the app
/// mid-workout doesn't lose it — `restoreActiveSession(in:)` picks it back up
/// on launch.
@Observable
final class WorkoutController {
    private(set) var session: WorkoutSession?

    /// Set after a workout ends when the calendar event could not be written,
    /// so the UI can say so instead of failing silently.
    private(set) var calendarWriteFailed = false

    private let calendarSync = CalendarSyncService()
    private let liveActivity = WorkoutLiveActivityController()

    var isRunning: Bool {
        session != nil
    }

    var activeList: RoutineList? {
        session?.list
    }

    /// Whether a workout is running for `list` specifically.
    func isRunning(for list: RoutineList) -> Bool {
        session?.list?.persistentModelID == list.persistentModelID
    }

    /// Reattaches to a workout left running by a previous launch.
    func restoreActiveSession(in context: ModelContext) {
        guard session == nil else { return }

        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        session = try? context.fetch(descriptor).first

        if let session {
            liveActivity.start(for: session)
        }
    }

    func start(list: RoutineList, in context: ModelContext) {
        guard session == nil else { return }

        let newSession = WorkoutSession(list: list)
        context.insert(newSession)
        session = newSession
        calendarWriteFailed = false

        liveActivity.start(for: newSession)
    }

    /// Ends the workout and, when the setting is on, writes it to the calendar.
    ///
    /// The event is created here rather than at the start so a single
    /// write-only permission covers it and the event already has its real
    /// duration — while still appearing at the hour the workout began.
    func end(in context: ModelContext) async {
        guard let session else { return }

        let end = Date()
        session.endDate = end
        self.session = nil
        calendarWriteFailed = false

        await liveActivity.end()

        guard UserDefaults.standard.bool(forKey: SettingsKey.syncWorkoutsToCalendar) else { return }

        let identifier = await calendarSync.addWorkoutEvent(
            title: session.listName,
            start: session.startDate,
            end: end
        )

        if let identifier {
            session.calendarEventIdentifier = identifier
        } else {
            calendarWriteFailed = true
        }
    }

    func dismissCalendarWarning() {
        calendarWriteFailed = false
    }
}
