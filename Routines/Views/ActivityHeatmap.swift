//
//  ActivityHeatmap.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A month of a whole list's activity, shaded the way a contribution graph is.
///
/// Inside a list, each day is a square in the list's colour, deeper the more of
/// its routines were completed that day. All shows several lists at once, so
/// there a day splits into vertical stripes, one in each list's colour, each
/// shaded by how much of that list was completed — a square then reads as both
/// "which lists" and "how much".
///
/// The rows are weeks. The selected one is highlighted, and tapping a day picks
/// its week, which the routines below the graph then show instead of this one.
struct ActivityHeatmap: View {
    /// The routines to chart, grouped the way the screen groups them. Each
    /// section draws in its own colour.
    let sections: [RoutineSection]
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

    init(sections: [RoutineSection], tint: Color, selectedWeekStart: Binding<Date?>) {
        self.sections = sections
        self.tint = tint
        _selectedWeekStart = selectedWeekStart
        let reference = selectedWeekStart.wrappedValue ?? Date()
        monthStart = Calendar.current.dateInterval(of: .month, for: reference)?.start ?? Date()
    }

    var body: some View {
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
        let activity = RoutineStore.activity(
            from: DayKey(monthStart, calendar: calendar),
            through: DayKey(monthEnd, calendar: calendar),
            across: sections
        )

        VStack(spacing: 10) {
            header
            weekdayHeader
            weekRows(activity: activity)
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
    private func weekRows(activity: [Int: [SectionActivity]]) -> some View {
        let currentWeekStart = currentWeekStart
        let todayKey = DayKey(Date(), calendar: calendar)

        return VStack(spacing: Self.cellSpacing + 2) {
            ForEach(weeks, id: \.self) { week in
                weekRow(week, activity: activity, currentWeekStart: currentWeekStart, todayKey: todayKey)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekRow(
        _ week: [Date?],
        activity: [Int: [SectionActivity]],
        currentWeekStart: Date,
        todayKey: DayKey
    ) -> some View {
        let weekStart = start(ofWeekContaining: week)
        let isSelected = weekStart.map(isSelected) ?? false
        let isCurrent = weekStart.map { DayKey($0, calendar: calendar) == DayKey(currentWeekStart, calendar: calendar) } ?? false

        return HStack(spacing: Self.cellSpacing) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                Group {
                    if let day {
                        let key = DayKey(day, calendar: calendar)
                        cell(
                            for: day,
                            activity: activity[key.value] ?? [],
                            isToday: key == todayKey,
                            isFutureWeek: (weekStart ?? day) > currentWeekStart,
                            weekStart: weekStart
                        )
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
        guard let day = week.compactMap({ $0 }).first else { return nil }
        return calendar.dateInterval(of: .weekOfYear, for: day)?.start
    }

    private var currentWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private func isSelected(_ weekStart: Date) -> Bool {
        DayKey(weekStart, calendar: calendar) == DayKey(selectedWeekStart ?? currentWeekStart, calendar: calendar)
    }

    // MARK: - Cells

    private func cell(
        for day: Date,
        activity: [SectionActivity],
        isToday: Bool,
        isFutureWeek: Bool,
        weekStart: Date?
    ) -> some View {
        Button {
            select(weekStart)
        } label: {
            DayStripes(activity: activity, emptyFill: Color.primary.opacity(isFutureWeek ? 0.04 : 0.08)) { stripe in
                shade(of: stripe.color, level: level(completed: stripe.completed, total: stripe.total))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isToday ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.5)
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

    private func accessibilityValue(for activity: [SectionActivity]) -> Text {
        let completed = activity.reduce(0) { $0 + $1.completed }
        if completed == 0 {
            return Text("Nothing completed", comment: "Accessibility value for a day in the activity heatmap with no routine completed")
        }
        return Text("\(completed) completed", comment: "Accessibility value for a day in the activity heatmap: how many routines were completed")
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

    /// The shade for `completed` routines out of `total`.
    private func level(completed: Int, total: Int) -> Int {
        guard total > 0, completed > 0 else { return 0 }
        let ratio = Double(completed) / Double(total)
        // A single completed routine earns the first shade, so a day with
        // something done never looks like one with nothing.
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
        let earliest = sections.flatMap(\.routines).map(\.createdAt).min() ?? Date()
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

#if DEBUG
#Preview("Earlier Week Selected") {
    @Previewable @State var selected: Date? = Calendar.current.date(
        byAdding: .day,
        value: -7,
        to: WeekPlanner.week(containing: Date()).first ?? Date()
    )

    List {
        ActivityHeatmap(
            sections: [
                RoutineSection(
                    id: nil,
                    title: nil,
                    color: .orange,
                    routines: (try? PreviewData.container.mainContext.fetch(FetchDescriptor<Routine>())) ?? []
                ),
            ],
            tint: .orange,
            selectedWeekStart: $selected
        )
    }
    .modelContainer(PreviewData.container)
    .environment(\.locale, Locale(identifier: "he_IL"))
    .environment(\.layoutDirection, .rightToLeft)
}

// All, where each day splits into a stripe per list.
#Preview("All") {
    @Previewable @State var selected: Date?

    let routines = (try? PreviewData.container.mainContext.fetch(FetchDescriptor<Routine>())) ?? []
    let lists = (try? PreviewData.container.mainContext.fetch(
        FetchDescriptor<RoutineList>(sortBy: [SortDescriptor(\.sortIndex)])
    )) ?? []
    let sections = lists.filter { !$0.isSmart }.map { list in
        RoutineSection(
            id: list.persistentModelID,
            title: Text(list.name),
            color: list.color,
            routines: routines.filter { $0.list?.persistentModelID == list.persistentModelID }
        )
    }

    List {
        ActivityHeatmap(sections: sections, tint: .accentColor, selectedWeekStart: $selected)
    }
    .modelContainer(PreviewData.container)
    .environment(\.locale, Locale(identifier: "en_US"))
    .environment(\.layoutDirection, .leftToRight)
}
#endif

/// A day square split into one vertical stripe per list with something
/// completed that day — a single stripe filling the square inside a list.
///
/// Stripes run in reading order, so in a right-to-left layout the first list
/// sits on the right — the same side its section's name starts on.
private struct DayStripes: View {
    let activity: [SectionActivity]
    let emptyFill: Color
    let shade: (SectionActivity) -> Color

    var body: some View {
        if activity.isEmpty {
            Rectangle()
                .fill(emptyFill)
        } else {
            HStack(spacing: 0) {
                ForEach(activity, id: \.id) { stripe in
                    Rectangle()
                        .fill(shade(stripe))
                }
            }
        }
    }
}
