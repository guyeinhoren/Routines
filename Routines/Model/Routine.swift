//
//  Routine.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A habit the person wants to track.
///
/// Every property carries a default value, relationships are optional and no
/// unique constraints are declared, because CloudKit cannot represent any of
/// those. Keeping to that shape is what lets the same store sync across iPhone,
/// iPad, Mac and Apple Watch.
@Model
final class Routine {
    var name: String = ""

    /// Free-form notes. Named `details` rather than `description` to avoid
    /// colliding with `CustomStringConvertible`.
    var details: String = ""

    var symbolName: String = "checkmark.circle.fill"
    var colorIdentifier: String = RoutineColor.fallback.rawValue

    /// Length of a single repetition in seconds. Zero means the routine is
    /// untimed and therefore has no play button on the main screen.
    var durationSeconds: Int = 0

    /// How many times the routine should be performed each day.
    var repetitionsPerDay: Int = 1

    /// Position in the main list. Rewritten as a dense 0-based sequence whenever
    /// the person reorders, so gaps and ties never accumulate.
    var sortIndex: Int = 0

    var createdAt: Date = Date()

    /// Stored outside the database row so large photos don't bloat the store.
    @Attribute(.externalStorage) var imageData: Data?

    var tags: [RoutineTag]?

    @Relationship(deleteRule: .cascade, inverse: \RoutineCompletion.routine)
    var completions: [RoutineCompletion]?

    init(
        name: String = "",
        details: String = "",
        symbolName: String = "checkmark.circle.fill",
        colorIdentifier: String = RoutineColor.fallback.rawValue,
        durationSeconds: Int = 0,
        repetitionsPerDay: Int = 1,
        sortIndex: Int = 0,
        imageData: Data? = nil,
        tags: [RoutineTag] = []
    ) {
        self.name = name
        self.details = details
        self.symbolName = symbolName
        self.colorIdentifier = colorIdentifier
        self.durationSeconds = durationSeconds
        self.repetitionsPerDay = repetitionsPerDay
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.imageData = imageData
        self.tags = tags
        self.completions = []
    }
}

extension Routine {
    var routineColor: RoutineColor {
        RoutineColor(identifier: colorIdentifier)
    }

    var color: Color {
        routineColor.color
    }

    /// Only timed routines get a play button and a full-screen countdown.
    var isTimed: Bool {
        durationSeconds > 0
    }

    /// Guards against a stored zero or negative target, which would otherwise
    /// divide by zero when computing progress.
    var dailyTarget: Int {
        max(1, repetitionsPerDay)
    }

    var sortedTags: [RoutineTag] {
        (tags ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func completion(on day: DayKey) -> RoutineCompletion? {
        completions?.first { $0.dayKey == day.value }
    }

    func completedCount(on day: DayKey) -> Int {
        completion(on: day)?.count ?? 0
    }

    /// The share of the day's target that has been performed, from 0 to 1. This
    /// is what drives the gradual fill of a day square.
    func progress(on day: DayKey) -> Double {
        Double(min(completedCount(on: day), dailyTarget)) / Double(dailyTarget)
    }

    func isFullyComplete(on day: DayKey) -> Bool {
        completedCount(on: day) >= dailyTarget
    }

    func hasTag(_ tag: RoutineTag) -> Bool {
        (tags ?? []).contains { $0.persistentModelID == tag.persistentModelID }
    }
}
