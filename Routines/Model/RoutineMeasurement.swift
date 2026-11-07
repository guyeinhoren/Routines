//
//  RoutineMeasurement.swift
//  Routines
//

import SwiftData
import Foundation

/// The number a routine carried on one day — 30 kg on the day of a lift.
///
/// One record per routine per day: entering another number the same day
/// replaces it, so the history charts a single point for each day.
@Model
final class RoutineMeasurement {
    /// The `DayKey` value this record belongs to, in `yyyyMMdd` form.
    var dayKey: Int = 0

    /// Midnight of the day, so the chart can plot it without decoding `dayKey`.
    var date: Date = Date()

    var value: Double = 0

    var routine: Routine?

    init(day: DayKey, value: Double, calendar: Calendar = .current) {
        self.dayKey = day.value
        self.value = value
        var components = DateComponents()
        components.year = day.value / 10_000
        components.month = (day.value / 100) % 100
        components.day = day.value % 100
        self.date = calendar.date(from: components) ?? Date()
    }
}
