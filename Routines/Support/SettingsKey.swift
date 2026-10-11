//
//  SettingsKey.swift
//  Routines
//

import Foundation

/// Keys shared between the app and the preferences it exposes to the system.
///
/// On iOS these are the identifiers declared in `Settings.bundle`, which is
/// what makes the switches appear under Routines in the Settings app. The Mac
/// reads and writes the same keys from its own Settings window.
enum SettingsKey {
    /// Whether ending a workout writes an event to the person's calendar.
    static let syncWorkoutsToCalendar = "syncWorkoutsToCalendar"

    /// Whether a finished timer counts as one completed repetition.
    static let timerCountsAsCompletion = "timerCountsAsCompletion"

    /// Which sound plays when a routine's timer ends. Holds a `TimerSound`
    /// raw value.
    static let timerSound = "timerSound"

    /// Whether the screen stays on while a routine's timer is running.
    static let keepScreenOnDuringTimer = "keepScreenOnDuringTimer"

    /// The list that was open when the app was last left, so the next launch
    /// reopens it. Not a preference, so it has no entry in `Settings.bundle`.
    static let lastOpenedList = "lastOpenedList"

    /// Whether the welcome screen has been seen. Not a preference either.
    static let hasSeenWelcome = "hasSeenWelcome"

    /// A request to show the welcome screen again, set from Settings. The app
    /// clears it once it has shown the screen, so it works like a button even
    /// though `Settings.bundle` can only offer a switch.
    static let showWelcomeAgain = "showWelcomeAgain"

    /// Default values for keys the person has never touched.
    ///
    /// A `Settings.bundle` only writes its declared defaults once the settings
    /// pane is actually opened, so the app cannot rely on them being present.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            syncWorkoutsToCalendar: false,
            timerCountsAsCompletion: true,
            timerSound: TimerSound.gentle.rawValue,
            keepScreenOnDuringTimer: false,
            hasSeenWelcome: false,
            showWelcomeAgain: false,
        ])
    }
}

/// The sound a routine's timer plays when it reaches zero.
enum TimerSound: String, CaseIterable, Identifiable {
    /// A single soft chime — the default.
    case gentle
    /// A longer, louder ring, for when the gentle one would go unheard.
    case loud
    case off

    var id: String { rawValue }

    /// The sound file in the app bundle, or `nil` for silence.
    var fileName: String? {
        switch self {
        case .gentle: "TimerChimeGentle.wav"
        case .loud: "TimerChimeLoud.wav"
        case .off: nil
        }
    }

    static var current: TimerSound {
        TimerSound(rawValue: UserDefaults.standard.string(forKey: SettingsKey.timerSound) ?? "") ?? .gentle
    }
}
