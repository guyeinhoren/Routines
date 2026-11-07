//
//  AdvanceRoutineIntent.swift
//  Routines
//
//  KEEP IN STEP with RoutinesWidget/AdvanceRoutineIntent.swift. The widget
//  extension needs the type to draw a button for it; the system runs it in the
//  app, where this copy does the work. The extension's copy does nothing.
//

#if os(iOS)
import AppIntents

/// What today's square in the Live Activity does when tapped: the same step
/// the square on the main screen takes.
nonisolated struct AdvanceRoutineIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Update Routine"

    @Parameter(title: "Routine")
    var routineID: String

    init() {}

    init(routineID: String) {
        self.routineID = routineID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        RoutineStatusActivity.advance(routineID: routineID)
        return .result()
    }
}
#endif
