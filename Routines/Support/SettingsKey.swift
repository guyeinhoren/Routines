//
//  SettingsKey.swift
//  Routines
//

import Foundation

/// Keys shared between the app and the preferences it exposes to the system.
///
/// On iOS and iPadOS these are the identifiers declared in `Settings.bundle`,
/// which is what makes the switches appear under Routines in the Settings app.
/// The Mac reads and writes the same keys from its own Settings window.
enum SettingsKey {
    /// Whether ending a workout writes an event to the person's calendar.
    static let syncWorkoutsToCalendar = "syncWorkoutsToCalendar"

    /// Whether a finished timer counts as one completed repetition.
    static let timerCountsAsCompletion = "timerCountsAsCompletion"

    /// Default values for keys the person has never touched.
    ///
    /// A `Settings.bundle` only writes its declared defaults once the settings
    /// pane is actually opened, so the app cannot rely on them being present.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            syncWorkoutsToCalendar: false,
            timerCountsAsCompletion: true,
        ])
    }
}
