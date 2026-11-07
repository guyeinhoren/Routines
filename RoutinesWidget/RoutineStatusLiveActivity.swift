//
//  RoutineStatusLiveActivity.swift
//  RoutinesWidget
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The routine the person last tapped, on the Lock Screen and in the Dynamic
/// Island.
///
/// Today's square is a button that takes the same step the square in the list
/// does. Everywhere else a tap opens the app on the list the routine was
/// tapped in.
struct RoutineStatusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineStatusActivityAttributes.self) { context in
            RoutineStatusLockScreen(context: context)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(ActivityColor.color(for: context.attributes.colorIdentifier))
                .widgetURL(context.attributes.destinationURL)
        } dynamicIsland: { context in
            let tint = ActivityColor.color(for: context.attributes.colorIdentifier)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySymbol(symbolName: context.attributes.symbolName, tint: tint, size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RoutineCaption(state: context.state)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.routineName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WeekSquares(attributes: context.attributes, state: context.state, tint: tint, side: 30)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(tint)
            } compactTrailing: {
                RoutineCaption(state: context.state)
                    .foregroundStyle(tint)
            } minimal: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
            .widgetURL(context.attributes.destinationURL)
        }
    }
}

private struct RoutineStatusLockScreen: View {
    let context: ActivityViewContext<RoutineStatusActivityAttributes>

    var body: some View {
        let tint = ActivityColor.color(for: context.attributes.colorIdentifier)

        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ActivitySymbol(symbolName: context.attributes.symbolName, tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routineName)
                        .font(.headline)
                        .lineLimit(1)
                    if let valueText = context.state.valueText {
                        Text(valueText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                RoutineCaption(state: context.state)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            WeekSquares(attributes: context.attributes, state: context.state, tint: tint, side: 34)
        }
        .padding(16)
    }
}

/// Today's progress: a tick once the day is done, otherwise how far along.
private struct RoutineCaption: View {
    let state: RoutineStatusActivityAttributes.ContentState

    var body: some View {
        if state.doneToday >= state.target {
            Image(systemName: "checkmark.circle.fill")
        } else if state.target > 1 {
            Text("\(state.doneToday)/\(state.target)")
                .monospacedDigit()
        } else {
            Image(systemName: "circle")
        }
    }
}

/// The week's squares in the order the app lays them out, with today's one a
/// button.
private struct WeekSquares: View {
    let attributes: RoutineStatusActivityAttributes
    let state: RoutineStatusActivityAttributes.ContentState
    let tint: Color
    let side: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(state.weekProgress.enumerated()), id: \.offset) { index, progress in
                if index == state.todayIndex {
                    Button(intent: AdvanceRoutineIntent(routineID: attributes.routineID)) {
                        square(progress: progress, isToday: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    square(progress: progress, isToday: false)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func square(progress: Double, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)

        return ZStack(alignment: .bottom) {
            shape.fill(Color.primary.opacity(0.12))
            Rectangle()
                .fill(tint)
                .frame(height: side * max(0, min(1, progress)))
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(isToday ? tint : .clear, lineWidth: 2)
        }
        .frame(width: side, height: side)
        // A bigger target around today's square than its drawing, since it's
        // the one that takes a tap.
        .contentShape(.rect)
    }
}

#Preview("Routine", as: .content, using: RoutineStatusActivityAttributes(
    routineID: "",
    routineName: "Pull-Ups",
    symbolName: "figure.strengthtraining.functional",
    colorIdentifier: "orange",
    destinationURL: nil
)) {
    RoutineStatusLiveActivity()
} contentStates: {
    RoutineStatusActivityAttributes.ContentState(
        weekProgress: [1, 0.5, 1, 0, 0.5, 0, 0], todayIndex: 4, doneToday: 1, target: 2, valueText: "22.5 kg"
    )
    RoutineStatusActivityAttributes.ContentState(
        weekProgress: [1, 1, 1, 1, 1, 0, 0], todayIndex: 4, doneToday: 2, target: 2, valueText: nil
    )
}
