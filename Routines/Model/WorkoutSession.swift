//
//  WorkoutSession.swift
//  Routines
//

import SwiftData
import Foundation

/// A stretch of time once spent working through the routines of one list.
///
/// Retired: the app no longer starts workouts or writes them to Calendar. The
/// model stays in the schema only so stores that already hold sessions — on
/// this device or in iCloud — keep opening without a migration. Nothing reads
/// or writes it any more.
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
