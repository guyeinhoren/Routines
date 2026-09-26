//
//  MacSettingsView.swift
//  Routines
//

#if os(macOS)
import SwiftUI

/// The Mac's Settings window.
///
/// Reads and writes the same defaults keys that `Settings.bundle` exposes on
/// iOS and iPadOS, so a preference means the same thing on every platform.
struct MacSettingsView: View {
    @AppStorage(SettingsKey.syncWorkoutsToCalendar) private var syncWorkoutsToCalendar = false
    @AppStorage(SettingsKey.timerCountsAsCompletion) private var timerCountsAsCompletion = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $syncWorkoutsToCalendar) {
                    Text("Add Workouts to Calendar", comment: "Preference that writes workouts to the calendar")
                }
            } footer: {
                Text(
                    "When a workout ends, an event with the tag's name is added at the time the workout started.",
                    comment: "Explains the calendar preference"
                )
            }

            Section {
                Toggle(isOn: $timerCountsAsCompletion) {
                    Text("Finished Timer Counts as Done", comment: "Preference that records a repetition when a timer ends")
                }
            } footer: {
                Text(
                    "Running a routine's timer to the end records one repetition for today.",
                    comment: "Explains the timer completion preference"
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
    }
}
#endif
