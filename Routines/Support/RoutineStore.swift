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

    /// Moves `movingIDs` so they sit immediately before `beforeID`, or at the
    /// end when it is `nil`, then rewrites `sortIndex` across the whole list.
    static func reorder(
        _ routines: [Routine],
        moving movingIDs: [PersistentIdentifier],
        before beforeID: PersistentIdentifier?
    ) {
        let moving = Set(movingIDs)
        guard !moving.isEmpty else { return }

        var ordered = routines
        var moved: [Routine] = []
        moved.reserveCapacity(moving.count)
        ordered.removeAll { routine in
            guard moving.contains(routine.persistentModelID) else { return false }
            moved.append(routine)
            return true
        }

        if let beforeID {
            let index = ordered.firstIndex { $0.persistentModelID == beforeID } ?? ordered.endIndex
            ordered.insert(contentsOf: moved, at: index)
        } else {
            ordered.append(contentsOf: moved)
        }

        for (index, routine) in ordered.enumerated() where routine.sortIndex != index {
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
}
