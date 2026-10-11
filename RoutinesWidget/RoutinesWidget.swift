//
//  RoutinesWidget.swift
//  RoutinesWidget
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Routine timer

/// The Lock Screen and Dynamic Island while a routine's timer runs.
///
/// The countdown is drawn by the system from the end date the app hands over,
/// so it keeps ticking with the app suspended. Once that date passes the
/// activity is stale, which is taken to mean "done" even if the app hasn't had
/// a chance to say so.
struct RoutineTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineTimerActivityAttributes.self) { context in
            RoutineTimerLockScreen(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(ActivityColor.color(for: context.attributes.colorIdentifier))
        } dynamicIsland: { context in
            let tint = ActivityColor.color(for: context.attributes.colorIdentifier)
            let phase = TimerPhase(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySymbol(symbolName: context.attributes.symbolName, tint: tint, size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerReadout(phase: phase)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.routineName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimerProgress(phase: phase, totalSeconds: context.attributes.totalSeconds)
                        .tint(tint)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(tint)
            } compactTrailing: {
                TimerReadout(phase: phase)
                    .foregroundStyle(tint)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: phase.isDone ? "checkmark" : context.attributes.symbolName)
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }
}

/// Where the countdown stands, as the widget can tell it.
private enum TimerPhase {
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case done

    init(context: ActivityViewContext<RoutineTimerActivityAttributes>) {
        let state = context.state
        if state.isFinished || context.isStale {
            self = .done
        } else if let endDate = state.endDate {
            self = endDate <= Date() ? .done : .running(endDate: endDate)
        } else {
            self = .paused(remaining: state.remainingSeconds)
        }
    }

    var isDone: Bool {
        if case .done = self { true } else { false }
    }
}

private struct RoutineTimerLockScreen: View {
    let context: ActivityViewContext<RoutineTimerActivityAttributes>

    var body: some View {
        let tint = ActivityColor.color(for: context.attributes.colorIdentifier)
        let phase = TimerPhase(context: context)

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActivitySymbol(symbolName: context.attributes.symbolName, tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routineName)
                        .font(.headline)
                        .lineLimit(1)
                    statusLine(for: phase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                TimerReadout(phase: phase)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            TimerProgress(phase: phase, totalSeconds: context.attributes.totalSeconds)
                .tint(tint)
        }
        .padding(16)
    }

    private func statusLine(for phase: TimerPhase) -> Text {
        switch phase {
        case .running: Text("Timer", comment: "Live Activity status while a routine's timer runs")
        case .paused: Text("Paused", comment: "Live Activity status while a routine's timer is paused")
        case .done: Text("Done", comment: "Live Activity status once a routine's timer has ended")
        }
    }
}

/// The time left, live while running.
private struct TimerReadout: View {
    let phase: TimerPhase

    var body: some View {
        Group {
            switch phase {
            case .running(let endDate):
                Text(timerInterval: Date()...endDate, countsDown: true)
            case .paused(let remaining):
                Text(Self.format(remaining))
            case .done:
                Image(systemName: "checkmark.circle.fill")
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        let pattern: Duration.TimeFormatStyle.Pattern = whole >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(whole).formatted(.time(pattern: pattern))
    }
}

/// How much of the timer has gone, filling as the countdown runs.
private struct TimerProgress: View {
    let phase: TimerPhase
    let totalSeconds: Double

    var body: some View {
        switch phase {
        case .running(let endDate):
            // The countdown's effective start: however long it has been
            // paused, the bar shows how much of the whole length is left.
            ProgressView(
                timerInterval: endDate.addingTimeInterval(-totalSeconds)...endDate,
                countsDown: false
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        case .paused(let remaining):
            ProgressView(value: max(0, min(1, 1 - remaining / max(1, totalSeconds))))
        case .done:
            ProgressView(value: 1)
        }
    }
}

// MARK: - Workout

/// The Lock Screen and Dynamic Island while a workout is underway, counting
/// up from when it started.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            let tint = ActivityColor.color(for: context.attributes.colorIdentifier)

            HStack(spacing: 12) {
                ActivitySymbol(symbolName: context.attributes.symbolName, tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.listName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Workout", comment: "Live Activity status while a workout runs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(context.state.startDate, style: .timer)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(tint)
            }
            .padding(16)
            .activitySystemActionForegroundColor(tint)
        } dynamicIsland: { context in
            let tint = ActivityColor.color(for: context.attributes.colorIdentifier)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySymbol(symbolName: context.attributes.symbolName, tint: tint, size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .timer)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.listName)
                        .font(.headline)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(context.state.startDate, style: .timer)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(tint)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }
}

// MARK: - Shared pieces

/// A symbol in a filled circle of its colour, as the app draws lists.
private struct ActivitySymbol: View {
    let symbolName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The app's palette, by the identifiers it stores.
///
/// KEEP IN STEP with `RoutineColor` in the app. The extension can't import the
/// app's types, so the mapping is repeated; an unknown identifier falls back to
/// blue, as it does there.
enum ActivityColor {
    static func color(for identifier: String) -> Color {
        switch identifier {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        default: .blue
        }
    }
}

// MARK: - Previews

#Preview("Timer", as: .content, using: RoutineTimerActivityAttributes(
    routineName: "Meditate",
    symbolName: "figure.mind.and.body",
    colorIdentifier: "indigo",
    totalSeconds: 600
)) {
    RoutineTimerLiveActivity()
} contentStates: {
    RoutineTimerActivityAttributes.ContentState(endDate: Date().addingTimeInterval(420), remainingSeconds: 420, isFinished: false)
    RoutineTimerActivityAttributes.ContentState(endDate: nil, remainingSeconds: 185, isFinished: false)
    RoutineTimerActivityAttributes.ContentState(endDate: nil, remainingSeconds: 0, isFinished: true)
}

#Preview("Workout", as: .content, using: WorkoutActivityAttributes(
    listName: "Strength",
    symbolName: "dumbbell.fill",
    colorIdentifier: "red"
)) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(startDate: Date().addingTimeInterval(-754))
}
