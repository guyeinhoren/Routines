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

    /// The routine's tags, comma-separated, empty for none. Unlike the list,
    /// which a routine has exactly one of, a tag cuts across lists: a smart
    /// list gathers every routine carrying its tag, whichever list each one
    /// lives in.
    ///
    /// Kept as one string rather than an array so the CloudKit schema stays as
    /// it was when a routine could carry only one tag. Read it through `tags`.
    var tag: String = ""

    @Relationship(deleteRule: .cascade, inverse: \RoutineCompletion.routine)
    var completions: [RoutineCompletion]?

    /// Whether the routine carries a number of its own — a weight lifted, say —
    /// shown beside its name and charted over time. Off for most routines.
    var tracksValue: Bool = false

    /// The unit written after the number, such as "kg". May be empty.
    var valueUnit: String = ""

    /// The latest number, or `nil` while none has been entered. Earlier ones
    /// live on in `measurements`.
    var currentValue: Double?

    @Relationship(deleteRule: .cascade, inverse: \RoutineMeasurement.routine)
    var measurements: [RoutineMeasurement]?

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
        self.measurements = []
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

    /// The share of the day's target that `count` repetitions make up, from 0
    /// to 1. This is what drives the gradual fill of a day square.
    func progress(forCount count: Int) -> Double {
        Double(min(count, dailyTarget)) / Double(dailyTarget)
    }

    /// Every recorded count between `first` and `last`, inclusive, keyed by
    /// `DayKey` value and gathered in a single pass over the history.
    ///
    /// Screens that show many days use this rather than asking day by day.
    /// Each `completion(on:)` walks the whole history, and reading
    /// `completions` rebuilds the relationship's array every time — so a week
    /// of squares asked one at a time cost seven walks, and a month thirty.
    func completionCounts(from first: DayKey, through last: DayKey) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for completion in completions ?? [] {
            let key = completion.dayKey
            guard key >= first.value, key <= last.value else { continue }
            // Two devices recording the same day offline can sync in two
            // records; the larger count is the one the person reached.
            counts[key] = max(counts[key] ?? 0, completion.count)
        }
        return counts
    }

    /// The number and its unit as shown beside the name — "30 kg" — or `nil`
    /// when the routine doesn't track one or none has been entered.
    func valueDescription(locale: Locale = .current) -> String? {
        guard tracksValue, let currentValue else { return nil }
        let number = currentValue.formatted(.number.locale(locale))
        let unit = valueUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    /// Each of the routine's tags on its own.
    var tags: [String] {
        RoutineTag.split(tag)
    }

    /// Whether the routine shows in `list`: by membership for an ordinary list,
    /// by any one of its tags for a smart one.
    func belongs(to list: RoutineList) -> Bool {
        if let smartTag = list.smartTag {
            return tags.contains { RoutineTag.matches($0, smartTag) }
        }
        return self.list?.persistentModelID == list.persistentModelID
    }
}

/// The rules for writing and comparing tags.
enum RoutineTag {
    /// Trims the tag and drops a leading "#", so "#home", " home" and "home"
    /// are all stored the same way.
    static func normalized(_ tag: String) -> String {
        var result = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("#") {
            result.removeFirst()
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case-insensitive, so "Home" typed on one routine and "home" on another
    /// still land in the same smart list. An empty tag matches nothing.
    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalized(lhs)
        let right = normalized(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left.compare(right, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Splits typed text into separate tags at each comma, normalising each
    /// one and dropping empties and repeats. "home, #gym,,Home" is two tags.
    static func split(_ text: String) -> [String] {
        var result: [String] = []
        // The full-width and Arabic commas too, which some keyboards type in
        // place of the ASCII one.
        for piece in text.split(whereSeparator: { [",", "，", "،"].contains($0) }) {
            let tag = normalized(String(piece))
            guard !tag.isEmpty, !result.contains(where: { matches($0, tag) }) else { continue }
            result.append(tag)
        }
        return result
    }

    /// The stored form of a set of tags: separated by a comma and a space, so
    /// it reads naturally when shown back in the editor.
    static func joined(_ tags: [String]) -> String {
        tags.joined(separator: ", ")
    }

    /// Every distinct tag in use, spelled the way it was first written,
    /// sorted for a picker.
    static func all(in routines: [Routine]) -> [String] {
        var seen: [String] = []
        for tag in routines.flatMap(\.tags) {
            guard !seen.contains(where: { matches($0, tag) }) else { continue }
            seen.append(tag)
        }
        return seen.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
