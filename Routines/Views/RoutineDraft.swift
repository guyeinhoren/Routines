//
//  RoutineDraft.swift
//  Routines
//

import Foundation
import SwiftData

/// What the editor sheet is working on.
enum RoutineEditorTarget: Identifiable {
    case new
    case existing(Routine)

    var id: PersistentIdentifier? {
        switch self {
        case .new: nil
        case .existing(let routine): routine.persistentModelID
        }
    }
}

/// An editable copy of a routine's fields.
///
/// The editor works on a draft rather than on the stored object so that
/// Cancel really cancels: SwiftData writes changes straight through to the
/// store, which would otherwise make every keystroke permanent.
struct RoutineDraft {
    var name: String = ""
    var details: String = ""
    var symbolName: String = "checkmark.circle.fill"
    var color: RoutineColor = .fallback
    var imageData: Data?

    var isTimed: Bool = false
    var durationMinutes: Int = 5
    var durationSeconds: Int = 0

    var repetitionsPerDay: Int = 1
    var tagIDs: Set<PersistentIdentifier> = []

    init() {}

    init(routine: Routine) {
        name = routine.name
        details = routine.details
        symbolName = routine.symbolName
        color = routine.routineColor
        imageData = routine.imageData
        isTimed = routine.isTimed
        durationMinutes = routine.durationSeconds / 60
        durationSeconds = routine.durationSeconds % 60
        repetitionsPerDay = routine.dailyTarget
        tagIDs = Set((routine.tags ?? []).map(\.persistentModelID))
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A routine needs a name to be identifiable in the list, so that's the
    /// only thing the editor insists on.
    var isSaveable: Bool {
        !trimmedName.isEmpty
    }

    /// The configured length in seconds, or zero when the routine is untimed.
    ///
    /// A timed routine is clamped to at least one second: leaving both fields at
    /// zero while the Timed switch is on would otherwise silently produce an
    /// untimed routine and make the switch look broken.
    var totalDurationSeconds: Int {
        guard isTimed else { return 0 }
        return max(1, durationMinutes * 60 + durationSeconds)
    }

    var durationDescription: String {
        Duration.seconds(totalDurationSeconds).formatted(.time(pattern: .minuteSecond))
    }

    func apply(to routine: Routine, availableTags: [RoutineTag]) {
        routine.name = trimmedName
        routine.details = details
        routine.symbolName = symbolName
        routine.colorIdentifier = color.rawValue
        routine.imageData = imageData
        routine.durationSeconds = totalDurationSeconds
        routine.repetitionsPerDay = max(1, repetitionsPerDay)
        routine.tags = availableTags.filter { tagIDs.contains($0.persistentModelID) }
    }
}
