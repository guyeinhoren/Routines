//
//  RoutineCompletion.swift
//  Routines
//

import SwiftData
import Foundation

/// One day's worth of progress on a routine.
///
/// A record only exists once the routine has been performed at least once that
/// day, so an absent record and a count of zero mean the same thing.
@Model
final class RoutineCompletion {
    /// The `DayKey` value this record belongs to, in `yyyyMMdd` form.
    var dayKey: Int = 0

    /// Midnight of the day, kept alongside `dayKey` so the record can be
    /// formatted and charted without decoding the integer.
    var date: Date = Date()

    /// How many repetitions have been performed. Never exceeds the routine's
    /// daily target, because tapping past the target clears the record instead.
    var count: Int = 0

    var routine: Routine?

    init(day: DayKey, count: Int = 0, calendar: Calendar = .current) {
        self.dayKey = day.value
        self.count = count
        self.date = Self.startOfDay(for: day, calendar: calendar)
    }

    private static func startOfDay(for day: DayKey, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = day.value / 10_000
        components.month = (day.value / 100) % 100
        components.day = day.value % 100
        return calendar.date(from: components) ?? Date()
    }
}
