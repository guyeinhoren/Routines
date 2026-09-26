//
//  RoutinesApp.swift
//  Routines
//

import SwiftData
import SwiftUI

@main
struct RoutinesApp: App {
    init() {
        SettingsKey.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Routine.self,
            RoutineList.self,
            RoutineCompletion.self,
            WorkoutSession.self,
        ])

        // iOS and iPadOS surface the app's preferences through Settings.bundle
        // in the system Settings app. The Mac has no equivalent, so it gets a
        // Settings window backed by the same defaults keys.
        #if os(macOS)
        Settings {
            MacSettingsView()
        }
        #endif
    }
}
