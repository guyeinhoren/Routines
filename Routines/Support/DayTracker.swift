//
//  DayTracker.swift
//  Routines
//

import Foundation

/// Publishes which day "today" is, so the main screen moves its editable square
/// to the new day when midnight passes while the app is open.
@Observable
final class DayTracker {
    private(set) var today: DayKey = .today
    private(set) var week: [Date] = WeekPlanner.week(containing: Date())

    /// Recomputes the current day immediately. Called when the app returns to
    /// the foreground, where the device clock may have moved a long way.
    func refresh() {
        let now = Date()
        let day = DayKey(now)
        guard day != today else { return }
        today = day
        week = WeekPlanner.week(containing: now)
    }

    /// Sleeps until just after the next midnight, refreshes, and repeats.
    /// Waiting for the boundary rather than polling every minute keeps the
    /// view hierarchy from re-rendering when nothing has changed.
    func run() async {
        while !Task.isCancelled {
            refresh()

            guard let nextMidnight = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 0, second: 1),
                matchingPolicy: .nextTime
            ) else { return }

            let interval = max(1, nextMidnight.timeIntervalSinceNow)
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
        }
    }
}
