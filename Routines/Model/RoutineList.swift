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
/// This replaces the earlier free-form tags. Tags let a routine sit in several
/// groups at once, which made "start a workout for this group" ambiguous and
/// gave the main screen nothing to be a list *of*.
@Model
final class RoutineList {
    var name: String = ""
    var symbolName: String = "list.bullet"
    var colorIdentifier: String = RoutineColor.fallback.rawValue

    /// Position on the root screen, kept dense and 0-based.
    var sortIndex: Int = 0

    var createdAt: Date = Date()

    /// Nullify rather than cascade: deleting a list shouldn't take a routine's
    /// recorded history with it. Its routines become unassigned and stay
    /// reachable under All.
    @Relationship(deleteRule: .nullify, inverse: \Routine.list)
    var routines: [Routine]?

    /// Present only so `WorkoutSession.list` has an inverse. CloudKit refuses
    /// to load a store containing a one-directional relationship.
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
}
