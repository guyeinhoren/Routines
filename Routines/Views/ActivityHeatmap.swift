//
//  ActivityHeatmap.swift
//  Routines
//

import SwiftUI

/// A month of a whole list's activity, shaded the way a contribution graph is:
/// the more of the list's daily target was recorded, the darker the square.
///
/// Unlike a single routine's history, this aggregates every routine in the
/// list, so one square answers "how much did I do that day" rather than
/// "did I do this one thing".
struct ActivityHeatmap: View {
    let routines: [Routine]
    let tint: Color

    /// First moment of the month on show. No value at the declaration because
    /// `init` assigns it — the `@State` macro would otherwise keep the
    /// declaration's value.
    @State private var monthStart: Date

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    init(routines: [Routine], tint: Color) {
        self.routines = routines
        self.tint = tint
        monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            grid
            legend
        }
        .padding(.vertical, 4)
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
        HStack(spacing: 4) {
            ForEach(WeekPlanner.week(containing: Date(), calendar: calendar), id: \.self) { day in
                Text(day.formatted(.dateTime.weekday(.narrow).locale(locale)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 34)
            }
        }
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
                    .fill(shade(forLevel: level))
                    .frame(width: 10, height: 10)
            }

            Text("More", comment: "Upper end of the activity heatmap's scale")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Grid

    private var grid: some View {
        // Eager, not lazy: this sits in a list row. See `FixedColumnGrid`.
        FixedColumnGrid(items: cells, columns: 7) { day in
            Group {
                if let day {
                    cell(for: day)
                } else {
                    // Keeps the first of the month under the right weekday.
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            // Capped so the squares stay graph-sized. Left uncapped they
            // stretch to fill a Mac or iPad window and stop reading as a
            // contribution graph.
            .frame(maxWidth: 34)
        }
        .frame(maxWidth: .infinity)
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

    private func cell(for day: Date) -> some View {
        let key = DayKey(day, calendar: calendar)
        let todayKey = DayKey(Date(), calendar: calendar)
        let totals = RoutineStore.activity(on: key, across: routines)
        let level = level(recorded: totals.recorded, target: totals.target)

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(shade(forLevel: level))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(key == todayKey ? tint : .clear, lineWidth: 1.5)
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(locale))))
            .accessibilityValue(
                Text(
                    "\(totals.recorded) of \(totals.target) recorded",
                    comment: "Accessibility value for a day in the activity heatmap"
                )
            )
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

    private func shade(forLevel level: Int) -> AnyShapeStyle {
        guard level > 0 else { return AnyShapeStyle(Color.primary.opacity(0.08)) }
        let step = Double(level) / Double(Self.shadeCount)
        return AnyShapeStyle(tint.opacity(0.25 + 0.75 * step))
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
