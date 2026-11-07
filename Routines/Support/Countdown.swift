//
//  Countdown.swift
//  Routines
//

import Foundation

/// Drives the full-screen routine timer.
///
/// While running, the remaining time is derived from a wall-clock deadline
/// rather than by subtracting a fixed amount on every tick. Tick-based
/// countdowns drift whenever the app is throttled or backgrounded; a deadline
/// stays correct no matter how irregularly `tick()` gets a chance to run.
@Observable
final class Countdown {
    /// The configured length of the countdown, used for the progress ring.
    let total: TimeInterval

    private(set) var remaining: TimeInterval
    private(set) var isRunning = false
    private(set) var isFinished = false

    /// When the countdown will reach zero. `nil` while paused or finished.
    ///
    /// Readable so the Lock Screen and the end-of-timer notification can work
    /// from the same moment the screen counts down to.
    private(set) var deadline: Date?

    /// Where the progress ring is heading, from 0 to 1, and how long it has to
    /// get there. Each tick aims the ring at the next tick's position, so a
    /// linear animation over that interval moves it smoothly and exactly in
    /// step with the clock, with the app waking only once a second.
    private(set) var ringProgress: Double = 0
    private(set) var ringAnimationDuration: TimeInterval = 0.25

    init(seconds: Int) {
        total = max(1, TimeInterval(seconds))
        remaining = total
    }

    /// How much of the countdown has elapsed with `remaining` left, from 0 to 1.
    private func elapsedFraction(remaining: TimeInterval) -> Double {
        guard total > 0 else { return 1 }
        return min(1, max(0, (total - remaining) / total))
    }

    func start() {
        guard !isRunning, !isFinished else { return }
        deadline = Date().addingTimeInterval(remaining)
        isRunning = true
    }

    func pause() {
        guard isRunning else { return }
        if let deadline {
            remaining = max(0, deadline.timeIntervalSinceNow)
        }
        deadline = nil
        isRunning = false
        // Settle the ring where the time actually stopped.
        ringAnimationDuration = 0.25
        ringProgress = elapsedFraction(remaining: remaining)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// Refreshes `remaining` while the countdown runs, and returns once it's
    /// paused, finished or cancelled. Driven from the timer view's
    /// `.task(id:)` keyed on `isRunning`, so a resume starts it again.
    ///
    /// It wakes only when the displayed second changes, rather than polling:
    /// the screen shows whole seconds, so ten wake-ups a second redrew the
    /// timer nine times for nothing, and kept polling even while paused.
    func run() async {
        while !Task.isCancelled, isRunning, let deadline {
            let left = max(0, deadline.timeIntervalSinceNow)
            remaining = left

            guard left > 0 else {
                finish()
                return
            }

            // The display rounds up, so it changes as `left` crosses a whole
            // second. A crossing that has only just happened waits a full one.
            let fraction = left - left.rounded(.down)
            let wait = fraction > 0.01 ? fraction : min(1, left)

            ringAnimationDuration = wait
            ringProgress = elapsedFraction(remaining: left - wait)

            do {
                try await Task.sleep(for: .seconds(wait))
            } catch {
                return
            }
        }
    }

    private func finish() {
        remaining = 0
        isRunning = false
        isFinished = true
        deadline = nil
        ringAnimationDuration = 0.25
        ringProgress = 1
    }
}
