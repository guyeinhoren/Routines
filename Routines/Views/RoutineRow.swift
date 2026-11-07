//
//  RoutineRow.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A routine on the main screen, as a single line.
///
/// The line splits into two targets: the name opens the routine's details and
/// the squares area records a repetition for today. A timed routine's timer is
/// started from its details, which leaves the name as much room as possible.
struct RoutineRow: View, Equatable {
    let routine: Routine

    /// The days on show, already turned into keys by the list so seven rows
    /// don't each convert the same seven dates.
    let week: [DayKey]
    let today: DayKey

    /// Whether `week` is an earlier week picked in the activity graph rather
    /// than this one. Today isn't on screen then, so tapping the squares
    /// returns to this week instead of recording something invisible.
    var isShowingPastWeek = false
    var onReturnToCurrentWeek: () -> Void = {}

    let onOpenDetail: () -> Void

    /// The screen the row is on, which the Live Activity reopens.
    var destination: ListDestination = .all

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    /// Bumped on every tap so repeated taps each produce feedback and each pop
    /// the square; a value that merely toggled would go still on the second tap.
    @State private var tapCount = 0

    @ScaledMetric(relativeTo: .caption2) private var squareSide = RoutineRowMetrics.squareSide

    /// Compares what the row draws from, leaving out the closures. A closure is
    /// never equal to another, so without this every change on the list screen
    /// — a selection, edit mode — would redraw every row. The routine's own
    /// changes still redraw it, through observation.
    static func == (lhs: RoutineRow, rhs: RoutineRow) -> Bool {
        lhs.routine === rhs.routine
            && lhs.week == rhs.week
            && lhs.today == rhs.today
            && lhs.isShowingPastWeek == rhs.isShowingPastWeek
    }

    var body: some View {
        // One pass over the routine's history for the whole week, rather than
        // a search per square.
        let counts = routine.completionCounts(from: week.first ?? today, through: week.last ?? today)

        HStack(spacing: RoutineRowMetrics.columnSpacing) {
            nameButton
            weekStripButton(counts: counts)
        }
        .sensoryFeedback(.increase, trigger: tapCount)
    }

    private var nameButton: some View {
        Button(action: onOpenDetail) {
            HStack(spacing: 8) {
                Text(routine.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // The routine's own number, such as a weight, beside its name.
                if let value = routine.valueDescription(locale: locale) {
                    Text(value)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows the routine's details.", comment: "VoiceOver hint for the routine name"))
    }

    private func weekStripButton(counts: [Int: Int]) -> some View {
        let color = routine.color

        // Today's square records a repetition; every other square opens the
        // routine, where that day can be filled in.
        return HStack(spacing: RoutineRowMetrics.squareSpacing) {
            ForEach(week, id: \.self) { key in
                let isToday = key == today && !isShowingPastWeek
                Button(action: isToday ? advanceToday : onOpenDetail) {
                    DaySquare(
                        progress: routine.progress(forCount: counts[key.value] ?? 0),
                        color: color,
                        isToday: key == today,
                        isFuture: key > today,
                        side: squareSide,
                        pulseTrigger: tapCount
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isShowingPastWeek
                ? Text("Selected week", comment: "VoiceOver label for the day squares while an earlier week is shown")
                : Text("This week", comment: "VoiceOver label for the week of day squares")
        )
        .accessibilityValue(progressDescription(counts: counts))
        .accessibilityHint(
            isShowingPastWeek
                ? Text("Shows the routine's details.", comment: "VoiceOver hint for the day squares while an earlier week is shown")
                : Text(
                    "Records one repetition for today. Tap again once the daily target is met to clear today.",
                    comment: "VoiceOver hint for the routine row"
                )
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if isShowingPastWeek { onOpenDetail() } else { advanceToday() }
        }
    }

    /// Today's progress followed by the week's, so one focus gives VoiceOver
    /// both what the tap will change and the context the squares convey visually.
    private func progressDescription(counts: [Int: Int]) -> Text {
        let target = routine.dailyTarget
        let done = counts[today.value] ?? 0
        let complete = week.count { (counts[$0.value] ?? 0) >= target }

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
        guard !isShowingPastWeek else {
            onOpenDetail()
            return
        }
        RoutineStore.advance(routine, on: today, in: context)
        tapCount += 1
        #if os(iOS)
        // The routine just tapped is the one the Lock Screen follows.
        RoutineStatusActivity.show(routine, destination: destination)
        #endif
    }
}

/// The initials of the week, sitting above the routines' square columns.
///
/// Mirrors `RoutineRow`'s layout exactly — a flexible leading column where the
/// name goes, then one cell per square — so the letters land over the columns
/// they label.
///
/// In All, where routines are grouped by list as in Reminders, the leading
/// column carries the list's name in its colour.
struct WeekdayHeader: View {
    let week: [Date]
    let today: DayKey
    var title: Text?
    var titleColor: Color = .primary

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .caption2) private var squareSide = RoutineRowMetrics.squareSide

    var body: some View {
        HStack(spacing: RoutineRowMetrics.columnSpacing) {
            if let title {
                title
                    .font(.title3.weight(.bold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Spacer(minLength: 0)
            }

            HStack(spacing: RoutineRowMetrics.squareSpacing) {
                ForEach(week, id: \.self) { day in
                    let isToday = DayKey(day) == today
                    Text(day.formatted(.dateTime.weekday(.narrow).locale(locale)))
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                        .frame(width: squareSide)
                }
            }
            // The full day names would be read out seven times before every
            // screen of routines; each square already carries its own date.
            .accessibilityHidden(true)
        }
    }
}
