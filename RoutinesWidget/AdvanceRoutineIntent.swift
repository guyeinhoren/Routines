//
//  AdvanceRoutineIntent.swift
//  RoutinesWidget
//
//  KEEP IN STEP with Routines/Shared/AdvanceRoutineIntent.swift. The extension
//  only needs the type to draw a button for it; the system runs the intent in
//  the app, where the other copy does the work. This one does nothing.
//

#if os(iOS)
import AppIntents

nonisolated struct AdvanceRoutineIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Update Routine"

    @Parameter(title: "Routine")
    var routineID: String

    init() {}

    init(routineID: String) {
        self.routineID = routineID
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
#endif
