//
//  RoutineHistoryCalendar.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A month of a routine's history: every day filled in proportion to how much
/// of that day's target was performed, with earlier months reachable.
struct RoutineHistoryCalendar: View {
    let routine: Routine

    /// When true, tapping a past day records a repetition for it, so a day
    /// missed at the time can be filled in afterwards. Read-only otherwise —
    /// the main screen should never rewrite history by accident.
    var isEditable: Bool = false

    /// First moment of the month on show. No value at the declaration because
    /// `init` assigns it — the `@State` macro would otherwise keep the
    /// declaration's value and ignore the one computed here.
    @State private var monthStart: Date

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var context

    init(routine: Routine, isEditable: Bool = false) {
        self.routine = routine
        self.isEditable = isEditable
        monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            monthGrid
        }
        .padding(.vertical, 6)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            stepButton(
                by: -1,
                systemImage: "chevron.backward",
                isEnabled: canStepBack,
                label: Text("Previous month", comment: "VoiceOver label for the calendar's back button")
            )

            Spacer()

            Text(monthStart.formatted(.dateTime.month(.wide).year().locale(locale)))
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())

            Spacer()

            stepButton(
                by: 1,
                systemImage: "chevron.forward",
                isEnabled: canStepForward,
                label: Text("Next month", comment: "VoiceOver label for the calendar's forward button")
            )
        }
    }

    private func stepButton(by months: Int, systemImage: String, isEnabled: Bool, label: Text) -> some View {
        Button {
            step(by: months)
        } label: {
            Image(systemName: systemImage)
                .frame(minWidth: 32, minHeight: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(WeekPlanner.week(containing: Date(), calendar: calendar), id: \.self) { day in
                Text(day.formatted(.dateTime.weekday(.narrow).locale(locale)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Grid

    private var monthGrid: some View {
        // Eager, not lazy: this sits in a form row. See `FixedColumnGrid`.
        FixedColumnGrid(items: cells, columns: 7) { day in
            if let day {
                cell(for: day)
            } else {
                // Keeps the first of the month under the right weekday.
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    /// The month's days, preceded by blanks so the first lands on its weekday.
    private var cells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        let days: [Date?] = dayRange.compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 1, to: monthStart)
        }

        return Array(repeating: nil, count: leadingBlanks) + days
    }

    @ViewBuilder private func cell(for day: Date) -> some View {
        let key = DayKey(day, calendar: calendar)
        let todayKey = DayKey(Date(), calendar: calendar)
        let isFuture = key > todayKey

        // Future days can't be recorded, so they stay inert even in edit mode.
        if isEditable, !isFuture {
            Button {
                record(on: key)
            } label: {
                cellContent(day: day, key: key, isToday: key == todayKey, isFuture: false)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Records a repetition for this day.", comment: "VoiceOver hint for an editable history day"))
        } else {
            cellContent(day: day, key: key, isToday: key == todayKey, isFuture: isFuture)
        }
    }

    private func cellContent(day: Date, key: DayKey, isToday: Bool, isFuture: Bool) -> some View {
        let progress = routine.progress(on: key)

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(isFuture ? 0.04 : 0.08))

            BottomFillShape(fraction: progress)
                .fill(routine.color)
                .animation(.bouncy(duration: 0.4, extraBounce: 0.2), value: progress)

            Text(day.formatted(.dateTime.day().locale(locale)))
                .font(.caption2)
                // White once the square is nearly full, where the routine's
                // colour would otherwise swallow the number.
                .foregroundStyle(progress > 0.6 ? Color.white : Color.primary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isToday ? routine.color : .clear, lineWidth: 1.5)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(locale))))
        .accessibilityValue(accessibilityValue(progress: progress, isFuture: isFuture))
    }

    private func accessibilityValue(progress: Double, isFuture: Bool) -> Text {
        if isFuture {
            return Text("Upcoming", comment: "Accessibility value for a future day in the history calendar")
        }
        if progress >= 1 {
            return Text("Complete", comment: "Accessibility value for a fully completed day")
        }
        if progress > 0 {
            return Text("Partly complete", comment: "Accessibility value for a partly completed day")
        }
        return Text("Nothing recorded", comment: "Accessibility value for a day with no progress")
    }

    // MARK: - Actions

    private func record(on day: DayKey) {
        RoutineStore.advance(routine, on: day, in: context)
    }

    // MARK: - Navigation

    /// The month the routine was created in. There is nothing to show before
    /// it, so stepping back stops there rather than running into empty months.
    private var earliestMonth: Date {
        calendar.dateInterval(of: .month, for: routine.createdAt)?.start ?? monthStart
    }

    private var currentMonth: Date {
        calendar.dateInterval(of: .month, for: Date())?.start ?? monthStart
    }

    private var canStepBack: Bool {
        monthStart > earliestMonth
    }

    private var canStepForward: Bool {
        monthStart < currentMonth
    }

    private func step(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: monthStart) else { return }
        withAnimation(.snappy) {
            monthStart = next
        }
    }
}
