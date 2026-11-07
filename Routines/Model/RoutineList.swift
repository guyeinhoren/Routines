//
//  RoutineList.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A named collection of routines, in the sense Reminders uses the word: a
/// routine belongs to exactly one list, and the lists are independent of each
/// other.
///
/// A smart list is the exception, as in Reminders: it has a `smartTag` and,
/// instead of members, shows every routine carrying that tag. Tags cut across
/// lists, so a routine stays in its one list while also appearing in any
/// number of smart lists' views — but only ever through its single tag.
@Model
final class RoutineList {
    var name: String = ""
    var symbolName: String = "list.bullet"
    var colorIdentifier: String = RoutineColor.fallback.rawValue

    /// Position on the root screen, kept dense and 0-based.
    var sortIndex: Int = 0

    /// Whether the list sits as a tile at the top of the root screen, the way
    /// Reminders shows pinned lists, rather than in the list below.
    var isPinned: Bool = false

    /// Set for a smart list: the tag whose routines it gathers. A smart list
    /// owns no routines of its own — it shows every routine carrying the tag,
    /// whichever list that routine belongs to. `nil` for an ordinary list.
    var smartTag: String?

    var createdAt: Date = Date()

    /// Nullify rather than cascade: deleting a list shouldn't take a routine's
    /// recorded history with it. Its routines become unassigned and stay
    /// reachable under All.
    @Relationship(deleteRule: .nullify, inverse: \Routine.list)
    var routines: [Routine]?

    /// Present only so the retired `WorkoutSession.list` has an inverse.
    /// CloudKit refuses to load a store containing a one-directional
    /// relationship.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.list)
    var workoutSessions: [WorkoutSession]?

    init(
        name: String = "",
        symbolName: String = "list.bullet",
        colorIdentifier: String = RoutineColor.fallback.rawValue,
        sortIndex: Int = 0
    ) {
        self.name = name
        self.symbolName = symbolName
        self.colorIdentifier = colorIdentifier
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.routines = []
        self.workoutSessions = []
    }
}

extension RoutineList {
    var color: Color {
        RoutineColor(identifier: colorIdentifier).color
    }

    /// The list's routines in the order they appear on screen.
    var orderedRoutines: [Routine] {
        (routines ?? []).sorted { lhs, rhs in
            lhs.sortIndex == rhs.sortIndex
                ? lhs.createdAt < rhs.createdAt
                : lhs.sortIndex < rhs.sortIndex
        }
    }

    var routineCount: Int {
        routines?.count ?? 0
    }

    var isSmart: Bool {
        smartTag != nil
    }

    /// How many routines the list shows. A smart list has no members of its
    /// own, so it counts the routines that carry its tag.
    func routineCount(among allRoutines: [Routine]) -> Int {
        guard isSmart else { return routineCount }
        return allRoutines.count { $0.belongs(to: self) }
    }
}
