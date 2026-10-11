//
//  TimerCompanion.swift
//  Routines
//

import AVFoundation
import Foundation
import OSLog
import UserNotifications

#if os(iOS)
import ActivityKit
import UIKit
#endif

/// Everything that goes on around a routine's timer besides the countdown
/// itself: the end-of-timer sound, the Lock Screen's Live Activity, and keeping
/// the screen awake.
///
/// The sound reaches the person two ways, because the app can't always play it.
/// With the app open, it plays here. With the phone locked or the app in the
/// background, iOS suspends the app long before the timer ends, so a local
/// notification is scheduled for that moment carrying the same sound. iOS
/// shows no notification to an app that's in front, so the two never both
/// ring.
@MainActor
final class TimerCompanion {
    private static let logger = Logger(subsystem: "GuyEinhoren.Routines", category: "Timer")

    private let routineName: String
    private let symbolName: String
    private let colorIdentifier: String
    private let totalSeconds: Double

    /// One identifier per timer, so cancelling it can't touch another's.
    private let notificationID = "routineTimer.\(UUID().uuidString)"

    /// When the countdown is due to end, while it's running.
    private var endDate: Date?

    private var player: AVAudioPlayer?

    #if os(iOS)
    private var activity: Activity<RoutineTimerActivityAttributes>?
    #endif

    #if os(macOS)
    private var awakeToken: NSObjectProtocol?
    #endif

    init(routine: Routine) {
        routineName = routine.name
        symbolName = routine.symbolName
        colorIdentifier = routine.colorIdentifier
        totalSeconds = Double(max(1, routine.durationSeconds))
    }

    // MARK: - Timer events

    func didStart(endingAt endDate: Date) {
        self.endDate = endDate
        scheduleNotification(at: endDate)
        setScreenKeptAwake(UserDefaults.standard.bool(forKey: SettingsKey.keepScreenOnDuringTimer))
        showActivity(
            .init(endDate: endDate, remainingSeconds: endDate.timeIntervalSinceNow, isFinished: false),
            staleDate: endDate
        )
    }

    func didPause(remaining: TimeInterval) {
        endDate = nil
        cancelNotification()
        setScreenKeptAwake(false)
        showActivity(.init(endDate: nil, remainingSeconds: remaining, isFinished: false), staleDate: nil)
    }

    /// The countdown reached zero. `appIsActive` says whether the person can
    /// see the app right now.
    func didFinish(appIsActive: Bool) {
        // Only ring if the end is happening now. If the app was suspended
        // through it, the notification has already rung, and the finish being
        // noticed late on return shouldn't ring a second time.
        let isOnTime = endDate.map { Date().timeIntervalSince($0) < 2 } ?? false
        endDate = nil

        cancelNotification()
        setScreenKeptAwake(false)

        if appIsActive, isOnTime {
            Self.play(TimerSound.current, into: &player)
        }

        #if os(iOS)
        let finished = RoutineTimerActivityAttributes.ContentState(endDate: nil, remainingSeconds: 0, isFinished: true)
        if let activity {
            Task {
                // Left up for a few minutes, so a glance at the Lock Screen
                // still says the timer is done.
                await activity.end(
                    ActivityContent(state: finished, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(5 * 60))
                )
            }
        }
        activity = nil
        #endif
    }

    /// The timer screen closed, finished or not.
    func didClose() {
        endDate = nil
        cancelNotification()
        setScreenKeptAwake(false)

        #if os(iOS)
        if let activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
        #endif
    }

    // MARK: - Sound

    /// Plays `sound` once, keeping the player alive in `player` until it ends.
    /// Also used by the Mac's Settings window to let a sound be heard before
    /// choosing it.
    static func play(_ sound: TimerSound, into player: inout AVAudioPlayer?) {
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: nil)
        else { return }

        #if os(iOS)
        // Playback rather than ambient, so the end of a timer is heard with
        // the ring switch off, the way the Clock app's timer is. Other audio
        // is ducked under it rather than stopped.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
        #endif

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.play()
            player = newPlayer

            #if os(iOS)
            let duration = newPlayer.duration
            Task {
                try? await Task.sleep(for: .seconds(duration + 0.3))
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
            #endif
        } catch {
            logger.error("Could not play the timer sound: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Notification

    private func scheduleNotification(at date: Date) {
        let sound = TimerSound.current
        guard let fileName = sound.fileName else { return }

        let center = UNUserNotificationCenter.current()
        let id = notificationID
        let title = routineName
        let body = String(localized: "Time's up.", comment: "Notification body when a routine's timer ends")
        let interval = max(1, date.timeIntervalSinceNow)

        Task {
            // Asked the first time a timer starts, when the reason is obvious.
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            } catch {
                Self.logger.error("Could not schedule the timer notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    // MARK: - Screen

    private func setScreenKeptAwake(_ keepAwake: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = keepAwake
        #elseif os(macOS)
        if keepAwake, awakeToken == nil {
            awakeToken = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: "A routine's timer is running"
            )
        } else if !keepAwake, let awakeToken {
            ProcessInfo.processInfo.endActivity(awakeToken)
            self.awakeToken = nil
        }
        #endif
    }

    // MARK: - Live Activity

    #if os(iOS)
    private func showActivity(_ state: RoutineTimerActivityAttributes.ContentState, staleDate: Date?) {
        let content = ActivityContent(state: state, staleDate: staleDate)

        if let activity {
            Task { await activity.update(content) }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RoutineTimerActivityAttributes(
            routineName: routineName,
            symbolName: symbolName,
            colorIdentifier: colorIdentifier,
            totalSeconds: totalSeconds
        )
        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            Self.logger.error("Could not start the timer Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }
    #else
    private func showActivity(_ state: Never?, staleDate: Date?) {}
    #endif
}

#if !os(iOS)
// Live Activities are iPhone-only. On the Mac the calls above take this
// placeholder and do nothing.
private extension Optional where Wrapped == Never {
    init(endDate: Date?, remainingSeconds: Double, isFinished: Bool) {
        self = nil
    }
}
#endif
