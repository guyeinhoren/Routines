//
//  WorkoutSession.swift
//  Routines
//

import SwiftData
import Foundation

/// A stretch of time spent working through the routines of one list.
///
/// The session is persisted rather than held in memory so an in-progress
/// workout survives the app being force quit and can still be ended — and
/// written to the calendar — afterwards.
@Model
final class WorkoutSession {
    var startDate: Date = Date()

    /// `nil` while the workout is still running.
    var endDate: Date?

    /// The list's name and symbol captured at the moment the workout started,
    /// so the calendar entry and the history keep their identity even if the
    /// list is later renamed or deleted.
    var listName: String = ""
    var listSymbolName: String = "list.bullet"
    var listColorIdentifier: String = RoutineColor.fallback.rawValue

    var list: RoutineList?

    /// Identifier of the calendar event written for this session, if any.
    var calendarEventIdentifier: String?

    init(list: RoutineList, startDate: Date = Date()) {
        self.startDate = startDate
        self.endDate = nil
        self.listName = list.name
        self.listSymbolName = list.symbolName
        self.listColorIdentifier = list.colorIdentifier
        self.list = list
        self.calendarEventIdentifier = nil
    }
}

extension WorkoutSession {
    var isActive: Bool {
        endDate == nil
    }

    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }
}
