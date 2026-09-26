//
//  CalendarSyncService.swift
//  Routines
//

import EventKit
import Foundation
import OSLog

/// Writes finished workouts into the person's calendar.
///
/// Only write-only access is requested: the app never needs to read anything
/// back, and the event is created once the workout ends so both the start and
/// end time are already known. That keeps the app out of the person's existing
/// calendar data entirely.
@Observable
final class CalendarSyncService {
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "GuyEinhoren.Routines", category: "CalendarSync")

    /// Set when a write fails, so the UI can explain why nothing was added.
    private(set) var lastErrorDescription: String?

    /// Asks for permission to add events, returning whether it was granted.
    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestWriteOnlyAccessToEvents()
        } catch {
            logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
            lastErrorDescription = error.localizedDescription
            return false
        }
    }

    /// Adds an event titled `title` spanning `start` to `end`, so the workout
    /// shows up on the calendar at the hour it began.
    ///
    /// Returns the new event's identifier, or `nil` if permission was refused
    /// or there is no calendar available to write to.
    @discardableResult
    func addWorkoutEvent(title: String, start: Date, end: Date) async -> String? {
        guard await requestAccess() else { return nil }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            logger.error("No default calendar available for new events.")
            return nil
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        // A zero-length event renders as a bare marker in most calendar apps,
        // so give a workout that was ended immediately a visible minimum.
        event.endDate = max(end, start.addingTimeInterval(60))
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            lastErrorDescription = nil
            return event.eventIdentifier
        } catch {
            logger.error("Saving workout event failed: \(error.localizedDescription, privacy: .public)")
            lastErrorDescription = error.localizedDescription
            return nil
        }
    }
}
