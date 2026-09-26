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

    /// The plain-text rendering of the description. Named `details` rather than
    /// `description` to avoid colliding with `CustomStringConvertible`.
    ///
    /// Kept alongside `detailsRichData` so emptiness checks, VoiceOver and any
    /// future search never have to decode the archive.
    var details: String = ""

    /// The description as archived rich text, or `nil` when it has no formatting
    /// or predates rich text support.
    var detailsRichData: Data?

    var symbolName: String = "repeat"
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

    /// The list this routine belongs to, or `nil` for a routine that isn't in
    /// any list yet. Unassigned routines still appear under All.
    var list: RoutineList?

    @Relationship(deleteRule: .cascade, inverse: \RoutineCompletion.routine)
    var completions: [RoutineCompletion]?

    init(
        name: String = "",
        details: String = "",
        symbolName: String = "repeat",
        colorIdentifier: String = RoutineColor.fallback.rawValue,
        durationSeconds: Int = 0,
        repetitionsPerDay: Int = 1,
        sortIndex: Int = 0,
        imageData: Data? = nil,
        list: RoutineList? = nil
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
        self.list = list
        self.completions = []
    }
}

extension Routine {
    /// The description as rich text.
    ///
    /// Routines saved before rich text existed fall back to their plain string,
    /// so nothing has to be migrated.
    var richDetails: AttributedString {
        RichText.decode(detailsRichData) ?? AttributedString(details)
    }

    var hasDetails: Bool {
        !details.isEmpty
    }

    /// Stores the description in both forms at once, keeping them in step.
    func setDetails(_ text: AttributedString) {
        detailsRichData = RichText.encode(text)
        details = String(text.characters)
    }

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

    func belongs(to list: RoutineList) -> Bool {
        self.list?.persistentModelID == list.persistentModelID
    }
}
