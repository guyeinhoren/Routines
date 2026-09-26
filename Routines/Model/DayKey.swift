//
//  DayKey.swift
//  Routines
//

import Foundation

/// A time-zone stable identifier for a single calendar day, encoded as `yyyyMMdd`
/// (so 19 September 2026 becomes `20260919`).
///
/// Completions are stored against this integer rather than a `Date` because a
/// stored `Date` shifts which day it belongs to when the person travels across
/// time zones, and because integer comparisons keep SwiftData predicates simple.
struct DayKey: Hashable, Codable, Comparable, Sendable {
    let value: Int

    init(value: Int) {
        self.value = value
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        value = (components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0)
    }

    static var today: DayKey {
        DayKey(Date())
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.value < rhs.value
    }
}

/// Helpers for laying out the week of day squares shown on the main screen.
enum WeekPlanner {
    /// The seven days of the week that contains `date`, ordered from the first
    /// weekday of the person's locale. For Hebrew and US English that is Sunday
    /// through Saturday; other locales get their own conventional week start.
    static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }
}
