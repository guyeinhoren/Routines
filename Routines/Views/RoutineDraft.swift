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
    var details: AttributedString = AttributedString()
    var symbolName: String = "repeat"
    var color: RoutineColor = .fallback
    var imageData: Data?

    var isTimed: Bool = false

    /// The whole configured length. Kept as one number so the picker owns the
    /// split into hours, minutes and seconds.
    var durationSeconds: Int = 300

    var repetitionsPerDay: Int = 1

    /// The list the routine belongs to, or `nil` for none.
    var listID: PersistentIdentifier?

    /// The tags as typed, comma-separated. Split into separate tags on save.
    var tag: String = ""

    /// Whether the routine carries a number — a weight, say — beside its name.
    var tracksValue: Bool = false
    var value: Double?
    var valueUnit: String = ""

    /// A routine added from a smart list takes that list's tag rather than
    /// membership — a smart list has no members — so it shows up where it was
    /// added.
    init(defaultList: RoutineList? = nil) {
        if let defaultList, let smartTag = defaultList.smartTag {
            tag = smartTag
        } else {
            listID = defaultList?.persistentModelID
        }
    }

    init(routine: Routine) {
        name = routine.name
        details = routine.richDetails
        symbolName = routine.symbolName
        color = routine.routineColor
        imageData = routine.imageData
        isTimed = routine.isTimed
        // An untimed routine keeps the default so turning the switch on offers
        // something sensible rather than zero.
        durationSeconds = routine.isTimed ? routine.durationSeconds : 300
        repetitionsPerDay = routine.dailyTarget
        listID = routine.list?.persistentModelID
        tag = routine.tag
        tracksValue = routine.tracksValue
        value = routine.currentValue
        valueUnit = routine.valueUnit
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
    /// A timed routine is clamped to at least one second: leaving every wheel at
    /// zero while the Timed switch is on would otherwise silently produce an
    /// untimed routine and make the switch look broken.
    var totalDurationSeconds: Int {
        guard isTimed else { return 0 }
        return max(1, durationSeconds)
    }

    /// Writes the draft into `routine`. A number that differs from the stored
    /// one is also recorded in the routine's history against `today`, which
    /// is what the value chart plots; `routine` must already be in `context`.
    func apply(to routine: Routine, availableLists: [RoutineList], today: DayKey, in context: ModelContext) {
        routine.name = trimmedName
        routine.setDetails(details)
        routine.symbolName = symbolName
        routine.colorIdentifier = color.rawValue
        routine.imageData = imageData
        routine.durationSeconds = totalDurationSeconds
        routine.repetitionsPerDay = max(1, repetitionsPerDay)
        routine.list = availableLists.first { $0.persistentModelID == listID && !$0.isSmart }
        routine.tag = RoutineTag.joined(RoutineTag.split(tag))

        routine.tracksValue = tracksValue
        routine.valueUnit = valueUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        if tracksValue, value != routine.currentValue {
            RoutineStore.setValue(value, for: routine, on: today, in: context)
        }
    }
}
