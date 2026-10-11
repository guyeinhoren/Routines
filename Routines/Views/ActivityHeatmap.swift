//
//  ActivityHeatmap.swift
//  Routines
//

import SwiftUI

/// A month of a whole list's activity, shaded the way a contribution graph is.
///
/// Each day is drawn in the colours of the routines done that day: one colour
/// fills the square, several split it into vertical stripes. Every stripe is
/// shaded by how much of that colour's routines was done, so a square reads as
/// both "what" and "how much" at once.
///
/// The rows are weeks. The selected one is highlighted, and tapping a day picks
/// its week, which the routines below the graph then show instead of this one.
struct ActivityHeatmap: View {
    let routines: [Routine]
    let tint: Color

    /// The first day of the week the routines below are showing, or `nil` for
    /// the current week.
    @Binding var selectedWeekStart: Date?

    /// First moment of the month on show. No value at the declaration because
    /// `init` assigns it — the `@State` macro would otherwise keep the
    /// declaration's value.
    @State private var monthStart: Date

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    init(routines: [Routine], tint: Color, selectedWeekStart: Binding<Date?>) {
        self.routines = routines
        self.tint = tint
        _selectedWeekStart = selectedWeekStart
        let reference = selectedWeekStart.wrappedValue ?? Date()
        monthStart = Calendar.current.dateInterval(of: .month, for: reference)?.start ?? Date()
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            weekRows
            legend
        }
        .padding(.vertical, 4)
        .onChange(of: selectedWeekStart) { _, newValue in
            // Returning to the current week brings its month back into view
            // too, or the highlighted row could be a month away.
            guard newValue == nil, monthStart != currentMonth else { return }
            withAnimation(.snappy) {
                monthStart = currentMonth
            }
        }
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
                .frame(minWidth: 30, minHeight: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        HStack(spacing: Self.cellSpacing) {
            ForEach(WeekPlanner.week(containing: Date(), calendar: calendar), id: \.self) { day in
                Text(day.formatted(.dateTime.weekday(.narrow).locale(locale)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: Self.cellSide)
            }
        }
        .frame(maxWidth: Self.rowWidth)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// The "less to more" scale a contribution graph uses, so the shades mean
    /// something without having to tap a square.
    private var legend: some View {
        HStack(spacing: 4) {
            Spacer()

            Text("Less", comment: "Lower end of the activity heatmap's scale")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(1...Self.shadeCount, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(shade(of: tint, level: level))
                    .frame(width: 10, height: 10)
            }

            Text("More", comment: "Upper end of the activity heatmap's scale")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Weeks

    /// Capped so the squares stay graph-sized. Left uncapped they stretch to
    /// fill a Mac window and stop reading as a contribution graph.
    private static let cellSide: CGFloat = 34
    private static let cellSpacing: CGFloat = 4
    private static let rowWidth = cellSide * 7 + cellSpacing * 6

    /// One row per week. Plain stacks rather than a lazy grid: this sits in a
    /// list row, where a lazy grid's sizing loops on the Mac (see
    /// `FixedColumnGrid`), and a row has to exist as a view to be highlighted.
    private var weekRows: some View {
        VStack(spacing: Self.cellSpacing + 2) {
            ForEach(weeks, id: \.self) { week in
                weekRow(week)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekRow(_ week: [Date?]) -> some View {
        let weekStart = start(ofWeekContaining: week)
        let isSelected = weekStart.map(isSelected) ?? false
        let isCurrent = weekStart.map { DayKey($0, calendar: calendar) == DayKey(currentWeekStart, calendar: calendar) } ?? false

        return HStack(spacing: Self.cellSpacing) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                Group {
                    if let day {
                        cell(for: day, weekStart: weekStart)
                    } else {
                        // Keeps the first of the month under the right weekday.
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .frame(maxWidth: Self.cellSide)
            }
        }
        .frame(maxWidth: Self.rowWidth)
        .padding(3)
        .background {
            // The selected week is filled; the current week keeps an outline
            // while another is selected, so "now" stays findable.
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? tint.opacity(0.16) : .clear)
                .strokeBorder(
                    isSelected ? tint.opacity(0.55) : (isCurrent ? tint.opacity(0.3) : .clear),
                    lineWidth: 1
                )
        }
        .animation(.snappy, value: isSelected)
    }

    /// The month's days, preceded and followed by blanks, cut into weeks.
    private var weeks: [[Date?]] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        let days: [Date?] = dayRange.compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 1, to: monthStart)
        }

        var cells = Array(repeating: nil, count: leadingBlanks) + days
        let trailingBlanks = (7 - cells.count % 7) % 7
        cells += Array(repeating: nil, count: trailingBlanks)

        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private func start(ofWeekContaining week: [Date?]) -> Date? {
        guard let day = week.compactMap(\.self).first else { return nil }
        return calendar.dateInterval(of: .weekOfYear, for: day)?.start
    }

    private var currentWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private func isSelected(_ weekStart: Date) -> Bool {
        DayKey(weekStart, calendar: calendar) == DayKey(selectedWeekStart ?? currentWeekStart, calendar: calendar)
    }

    // MARK: - Cells

    private func cell(for day: Date, weekStart: Date?) -> some View {
        let key = DayKey(day, calendar: calendar)
        let todayKey = DayKey(Date(), calendar: calendar)
        let activity = RoutineStore.activityByColor(on: key, across: routines)
        let isFutureWeek = (weekStart ?? day) > currentWeekStart

        return Button {
            select(weekStart)
        } label: {
            DayStripes(activity: activity, emptyFill: Color.primary.opacity(isFutureWeek ? 0.04 : 0.08)) { stripe in
                shade(of: stripe.color.color, level: level(recorded: stripe.recorded, target: stripe.target))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(key == todayKey ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.5)
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // A week that hasn't happened yet has no history to show.
        .disabled(isFutureWeek)
        .accessibilityLabel(Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(locale))))
        .accessibilityValue(accessibilityValue(for: activity))
        .accessibilityHint(Text("Shows this week's routines below.", comment: "VoiceOver hint for a day in the activity heatmap"))
    }

    private func accessibilityValue(for activity: [ColorActivity]) -> Text {
        let recorded = activity.reduce(0) { $0 + $1.recorded }
        if recorded == 0 {
            return Text("Nothing recorded", comment: "Accessibility value for a day with no progress")
        }
        return Text("\(recorded) recorded", comment: "Accessibility value for a day in the activity heatmap")
    }

    private func select(_ weekStart: Date?) {
        guard let weekStart else { return }
        withAnimation(.snappy) {
            // The current week is the default, so selecting it clears the
            // selection rather than pinning a copy of it.
            selectedWeekStart = DayKey(weekStart, calendar: calendar) == DayKey(currentWeekStart, calendar: calendar)
                ? nil
                : weekStart
        }
    }

    // MARK: - Shading

    /// Four filled shades plus an empty one, matching the granularity a
    /// contribution graph uses — enough to read a trend, few enough to tell
    /// the steps apart.
    private static let shadeCount = 4

    private func level(recorded: Int, target: Int) -> Int {
        guard target > 0, recorded > 0 else { return 0 }
        let ratio = Double(recorded) / Double(target)
        // Any activity at all earns the first shade, so a busy day and a
        // barely-started one never look identical.
        return max(1, min(Self.shadeCount, Int((ratio * Double(Self.shadeCount)).rounded(.up))))
    }

    private func shade(of color: Color, level: Int) -> Color {
        guard level > 0 else { return Color.primary.opacity(0.08) }
        let step = Double(level) / Double(Self.shadeCount)
        return color.opacity(0.25 + 0.75 * step)
    }

    // MARK: - Navigation

    /// The month the earliest routine was created in. There is nothing to show
    /// before it.
    private var earliestMonth: Date {
        let earliest = routines.map(\.createdAt).min() ?? Date()
        return calendar.dateInterval(of: .month, for: earliest)?.start ?? monthStart
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

/// A day square split into one vertical stripe per colour done that day.
///
/// Stripes run in reading order, so in a right-to-left layout the first colour
/// sits on the right — the same side the first routine's name starts on.
private struct DayStripes: View {
    let activity: [ColorActivity]
    let emptyFill: Color
    let shade: (ColorActivity) -> Color

    var body: some View {
        if activity.isEmpty {
            Rectangle()
                .fill(emptyFill)
        } else {
            HStack(spacing: 0) {
                ForEach(activity, id: \.color) { stripe in
                    Rectangle()
                        .fill(shade(stripe))
                }
            }
        }
    }
}
