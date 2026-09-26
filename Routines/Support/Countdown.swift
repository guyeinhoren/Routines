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

    /// When the countdown will reach zero. `nil` while paused.
    private var deadline: Date?

    init(seconds: Int) {
        total = max(1, TimeInterval(seconds))
        remaining = total
    }

    /// How much of the countdown has elapsed, from 0 to 1.
    var progress: Double {
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
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// Refreshes `remaining` until the countdown finishes or the task is
    /// cancelled. Driven from the timer view's `.task`.
    func run() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
            tick()
        }
    }

    private func tick() {
        guard isRunning, let deadline else { return }

        remaining = max(0, deadline.timeIntervalSinceNow)
        guard remaining <= 0 else { return }

        remaining = 0
        isRunning = false
        isFinished = true
        self.deadline = nil
    }
}
