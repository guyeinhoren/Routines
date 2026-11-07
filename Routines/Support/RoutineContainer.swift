//
//  RoutineContainer.swift
//  Routines
//

import SwiftData

/// The app's one store, reachable from outside the view hierarchy.
///
/// A Live Activity's button runs in the app's process without any view on
/// screen, so it needs the same container the windows use rather than one of
/// its own.
enum RoutineContainer {
    /// The store, synced to the person's private iCloud database.
    ///
    /// Spelled out rather than left to discovery, because the sync is what keeps
    /// someone's routines and history when they delete the app and install it
    /// again: the local file goes with the app, the iCloud copy doesn't, and a
    /// fresh install downloads it. The group container is pinned to `.none` so
    /// adding an App Group later — for a widget, say — can't quietly move the
    /// store somewhere new and start from an empty file.
    static let shared: ModelContainer = {
        #if DEBUG
        // Before the container exists, so its setup event isn't missed.
        CloudSyncDiagnostics.start()
        #endif

        let configuration = ModelConfiguration(
            groupContainer: .none,
            cloudKitDatabase: .private("iCloud.GuyEinhoren.Routines")
        )
        do {
            return try ModelContainer(
                for: Routine.self, RoutineList.self, RoutineCompletion.self, RoutineMeasurement.self, WorkoutSession.self,
                configurations: configuration
            )
        } catch {
            fatalError("Could not open the routines store: \(error)")
        }
    }()
}
