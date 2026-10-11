//
//  MacSettingsView.swift
//  Routines
//

#if os(macOS)
import AVFoundation
import SwiftUI

/// The Mac's Settings window.
///
/// Reads and writes the same defaults keys that `Settings.bundle` exposes on
/// iOS, so a preference means the same thing on every platform.
struct MacSettingsView: View {
    @AppStorage(SettingsKey.syncWorkoutsToCalendar) private var syncWorkoutsToCalendar = false
    @AppStorage(SettingsKey.timerCountsAsCompletion) private var timerCountsAsCompletion = true
    @AppStorage(SettingsKey.timerSound) private var timerSound = TimerSound.gentle
    @AppStorage(SettingsKey.keepScreenOnDuringTimer) private var keepScreenOnDuringTimer = false
    @AppStorage(SettingsKey.showWelcomeAgain) private var showWelcomeAgain = false

    /// Holds the player while a chosen sound previews.
    @State private var previewPlayer: AVAudioPlayer?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $syncWorkoutsToCalendar) {
                    Text("Add Workouts to Calendar", comment: "Preference that writes workouts to the calendar")
                }
            } footer: {
                Text(
                    "When a workout ends, an event with the list's name is added at the time the workout started.",
                    comment: "Explains the calendar preference"
                )
            }

            Section {
                Toggle(isOn: $timerCountsAsCompletion) {
                    Text("Finished Timer Counts as Done", comment: "Preference that records a repetition when a timer ends")
                }

                Picker(selection: $timerSound) {
                    ForEach(TimerSound.allCases) { sound in
                        sound.title.tag(sound)
                    }
                } label: {
                    Text("Sound When Done", comment: "Preference for the sound a timer plays when it ends")
                }

                Toggle(isOn: $keepScreenOnDuringTimer) {
                    Text("Keep Screen On", comment: "Preference that stops the display sleeping while a timer runs")
                }
            } footer: {
                Text(
                    "Running a routine's timer to the end records one repetition for today. Keeping the screen on uses more battery.",
                    comment: "Explains the timer preferences"
                )
            }

            Section {
                Button {
                    showWelcomeAgain = true
                } label: {
                    Text("Show Welcome Screen", comment: "Button that shows the welcome screen again")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
        .onChange(of: timerSound) { _, sound in
            // Picking a sound plays it, so it can be judged before the next
            // timer ends.
            TimerCompanion.play(sound, into: &previewPlayer)
        }
    }
}
#endif

extension TimerSound {
    /// The name shown wherever a sound is chosen.
    var title: Text {
        switch self {
        case .gentle: Text("Gentle Chime", comment: "Timer sound choice: a single soft chime")
        case .loud: Text("Loud Ring", comment: "Timer sound choice: a longer, louder ring")
        case .off: Text("None", comment: "Timer sound choice: no sound")
        }
    }
}
