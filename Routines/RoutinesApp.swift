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
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 440)
                #endif
        }
        #if os(macOS)
        // Reminders shows the list's name large in the content, not in the
        // title bar, so the title is kept for the Window menu and Mission
        // Control but left out of the toolbar.
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 980, height: 640)
        #endif
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
