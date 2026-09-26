//
//  RoutineRow.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A routine on the main screen, as a single line.
///
/// The line splits into two targets: the name opens the routine's details and
/// the squares area records a repetition for today. A timed routine also gets a
/// play button, in a slot that is reserved either way so the square columns
/// stay aligned down the list.
struct RoutineRow: View {
    let routine: Routine
    let week: [Date]
    let today: DayKey
    let onOpenDetail: () -> Void
    let onStartTimer: () -> Void

    @Environment(\.modelContext) private var context

    /// Bumped on every tap so repeated taps each produce feedback and each pop
    /// the square; a value that merely toggled would go still on the second tap.
    @State private var tapCount = 0

    @ScaledMetric(relativeTo: .caption2) private var squareSide = RoutineRowMetrics.squareSide

    var body: some View {
        HStack(spacing: RoutineRowMetrics.columnSpacing) {
            nameButton
            weekStripButton
            playSlot
        }
        .sensoryFeedback(.increase, trigger: tapCount)
    }

    private var nameButton: some View {
        Button(action: onOpenDetail) {
            Text(routine.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows the routine's details.", comment: "VoiceOver hint for the routine name"))
    }

    private var weekStripButton: some View {
        Button(action: advanceToday) {
            HStack(spacing: RoutineRowMetrics.squareSpacing) {
                ForEach(week, id: \.self) { day in
                    let key = DayKey(day)
                    DaySquare(
                        progress: routine.progress(on: key),
                        color: routine.color,
                        isToday: key == today,
                        isFuture: key > today,
                        side: squareSide,
                        pulseTrigger: tapCount
                    )
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("This week", comment: "VoiceOver label for the week of day squares"))
        .accessibilityValue(progressDescription)
        .accessibilityHint(
            Text(
                "Records one repetition for today. Tap again once the daily target is met to clear today.",
                comment: "VoiceOver hint for the routine row"
            )
        )
    }

    /// Reserves the play button's width for every routine, so a row without a
    /// timer doesn't let its squares slide across.
    @ViewBuilder private var playSlot: some View {
        if routine.isTimed {
            Button(action: onStartTimer) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(routine.color)
                    .frame(width: RoutineRowMetrics.playSlotWidth, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Start timer for \(routine.name)", comment: "VoiceOver label for the play button"))
        } else {
            Color.clear
                .frame(width: RoutineRowMetrics.playSlotWidth, height: 1)
                .accessibilityHidden(true)
        }
    }

    /// Today's progress followed by the week's, so one focus gives VoiceOver
    /// both what the tap will change and the context the squares convey visually.
    private var progressDescription: Text {
        let done = routine.completedCount(on: today)
        let target = routine.dailyTarget
        let complete = week.count { routine.isFullyComplete(on: DayKey($0)) }

        if target > 1 {
            return Text(
                "\(done) of \(target) done today, \(complete) of \(week.count) days complete this week",
                comment: "Accessibility value for a routine with several repetitions a day"
            )
        }
        return Text(
            "\(complete) of \(week.count) days complete this week",
            comment: "Accessibility value summarising the week"
        )
    }

    private func advanceToday() {
        RoutineStore.advance(routine, on: today, in: context)
        tapCount += 1
    }
}

/// The initials of the week, sitting above the routines' square columns.
///
/// Mirrors `RoutineRow`'s layout exactly — a flexible leading column where the
/// name goes, then one cell per square, then the reserved play slot — so the
/// letters land over the columns they label.
struct WeekdayHeader: View {
    let week: [Date]
    let today: DayKey

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .caption2) private var squareSide = RoutineRowMetrics.squareSide

    var body: some View {
        HStack(spacing: RoutineRowMetrics.columnSpacing) {
            Spacer(minLength: 0)

            HStack(spacing: RoutineRowMetrics.squareSpacing) {
                ForEach(week, id: \.self) { day in
                    let isToday = DayKey(day) == today
                    Text(day.formatted(.dateTime.weekday(.narrow).locale(locale)))
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                        .frame(width: squareSide)
                }
            }

            Color.clear
                .frame(width: RoutineRowMetrics.playSlotWidth, height: 1)
        }
        // The full day names would be read out seven times before every screen
        // of routines; each square already carries its own date.
        .accessibilityHidden(true)
    }
}
