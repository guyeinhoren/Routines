//
//  RoutineStore.swift
//  Routines
//

import SwiftData
import Foundation

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
    /// `orderedIDs` may cover only part of `all` — the main screen narrows to
    /// one tag while a workout runs. The reordered routines are slotted back
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

    /// The total number of repetitions recorded on `day` across `routines`,
    /// alongside the combined daily target.
    ///
    /// The heatmap shades a day by the ratio of these two, so a list of three
    /// routines needs all three done to reach its darkest shade.
    static func activity(on day: DayKey, across routines: [Routine]) -> (recorded: Int, target: Int) {
        routines.reduce(into: (recorded: 0, target: 0)) { totals, routine in
            totals.recorded += min(routine.completedCount(on: day), routine.dailyTarget)
            totals.target += routine.dailyTarget
        }
    }
}
