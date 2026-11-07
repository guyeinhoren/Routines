//
//  RoutineStore.swift
//  Routines
//

import SwiftData
import SwiftUI

/// Mutations on routines that need a `ModelContext`.
///
/// Keeping them here rather than in views means the main screen, the timer and
/// the editor all advance progress and reorder through exactly the same rules.
enum RoutineStore {
    /// Advances a routine's progress for `day` by one repetition, wrapping back
    /// to nothing once the daily target has been met.
    ///
    /// The wrap is deliberate: a day square is a single tap target, so tapping
    /// once more after finishing is the only way to undo a mistaken tap.
    static func advance(_ routine: Routine, on day: DayKey, in context: ModelContext) {
        guard let existing = routine.completion(on: day) else {
            let completion = RoutineCompletion(day: day, count: 1)
            context.insert(completion)
            completion.routine = routine
            return
        }

        let next = existing.count + 1
        if next > routine.dailyTarget {
            context.delete(existing)
        } else {
            existing.count = next
        }
    }

    /// Records one completed repetition without ever wrapping back to zero.
    /// Used when a timer runs to the end, where an accidental reset would throw
    /// away work the person actually did.
    static func recordRepetition(_ routine: Routine, on day: DayKey, in context: ModelContext) {
        guard let existing = routine.completion(on: day) else {
            let completion = RoutineCompletion(day: day, count: 1)
            context.insert(completion)
            completion.routine = routine
            return
        }
        existing.count = min(existing.count + 1, routine.dailyTarget)
    }

    /// Rewrites `sortIndex` so the routines named by `orderedIDs` take that
    /// relative order within `all`.
    ///
    /// `orderedIDs` may cover only part of `all` — a list shows only its own
    /// routines, and All moves them within one list's section. The reordered routines are slotted back
    /// into the positions that subset already occupied, so routines hidden by
    /// the filter keep their place.
    static func applyOrder(_ orderedIDs: [PersistentIdentifier], within all: [Routine]) {
        guard !orderedIDs.isEmpty else { return }

        let byID = Dictionary(all.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        let moving = Set(orderedIDs)

        var replacements = orderedIDs.makeIterator()
        var result: [Routine] = []
        result.reserveCapacity(all.count)

        for routine in all {
            guard moving.contains(routine.persistentModelID) else {
                result.append(routine)
                continue
            }
            if let nextID = replacements.next(), let next = byID[nextID] {
                result.append(next)
            }
        }

        for (index, routine) in result.enumerated() where routine.sortIndex != index {
            routine.sortIndex = index
        }
    }

    /// The index a newly created routine should take so it lands at the bottom.
    static func nextSortIndex(after routines: [Routine]) -> Int {
        (routines.map(\.sortIndex).max() ?? -1) + 1
    }

    static func delete(_ routine: Routine, in context: ModelContext) {
        context.delete(routine)
    }

    /// Sets the routine's number and records it against `day`, replacing any
    /// number already recorded for that day so the history keeps one point a
    /// day. A `nil` value clears the current number and leaves the history be.
    static func setValue(_ value: Double?, for routine: Routine, on day: DayKey, in context: ModelContext) {
        routine.currentValue = value
        guard let value else { return }

        let sameDay = (routine.measurements ?? []).filter { $0.dayKey == day.value }
        if let existing = sameDay.first {
            existing.value = value
            // Two devices recording the same day offline can sync in two
            // records; keep one.
            for duplicate in sameDay.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            let measurement = RoutineMeasurement(day: day, value: value)
            context.insert(measurement)
            measurement.routine = routine
        }
    }

    // MARK: - Lists

    /// The index a newly created list should take so it lands at the bottom.
    static func nextSortIndex(after lists: [RoutineList]) -> Int {
        (lists.map(\.sortIndex).max() ?? -1) + 1
    }

    /// Rewrites `sortIndex` so the lists take the order they appear in.
    static func applyOrder(_ lists: [RoutineList]) {
        for (index, list) in lists.enumerated() where list.sortIndex != index {
            list.sortIndex = index
        }
    }

    /// Removes a list, leaving its routines in place but unassigned.
    static func delete(_ list: RoutineList, in context: ModelContext) {
        context.delete(list)
    }

    /// The heatmap's activity for every day from `first` through `last`,
    /// keyed by `DayKey` value: one entry per section that had anything
    /// completed that day — a single entry inside a list, one per list in All.
    ///
    /// A section counts its routines fully done that day against how many it
    /// has, so a list of three needs all three done to reach its darkest
    /// shade. Sections with nothing done are left out, and the rest keep the
    /// order they're shown in, so a day's stripes line up the same way every
    /// time.
    ///
    /// Built for the whole range at once — one pass over each routine's
    /// history — rather than day by day, which walked every history once for
    /// each of a month's days.
    static func activity(
        from first: DayKey,
        through last: DayKey,
        across sections: [RoutineSection]
    ) -> [Int: [SectionActivity]] {
        var result: [Int: [SectionActivity]] = [:]

        for section in sections {
            var completedByDay: [Int: Int] = [:]
            for routine in section.routines {
                let target = routine.dailyTarget
                for (day, count) in routine.completionCounts(from: first, through: last) where count >= target {
                    completedByDay[day, default: 0] += 1
                }
            }

            for (day, completed) in completedByDay {
                result[day, default: []].append(SectionActivity(
                    id: section.id,
                    color: section.color,
                    completed: completed,
                    total: section.routines.count
                ))
            }
        }
        return result
    }
}

/// How many of one section's routines were completed on a day.
struct SectionActivity: Equatable {
    let id: PersistentIdentifier?
    let color: Color
    let completed: Int
    let total: Int
}
