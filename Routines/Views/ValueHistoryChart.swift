//
//  ValueHistoryChart.swift
//  Routines
//

import Charts
import SwiftUI

/// The routine's number over time — a smooth line through one point per day it
/// was entered, so a trend such as a rising weight reads at a glance.
struct ValueHistoryChart: View {
    let routine: Routine

    @Environment(\.locale) private var locale

    @State private var range: HistoryRange = .threeMonths

    /// The date under the finger or pointer, which picks the point described
    /// above the chart. `nil` describes the latest one.
    @State private var selectedDate: Date?

    enum HistoryRange: String, CaseIterable, Identifiable {
        case month, threeMonths, year, all

        var id: String { rawValue }

        var title: Text {
            switch self {
            case .month: Text("1M", comment: "Chart range: the last month, abbreviated")
            case .threeMonths: Text("3M", comment: "Chart range: the last three months, abbreviated")
            case .year: Text("1Y", comment: "Chart range: the last year, abbreviated")
            case .all: Text("All", comment: "Chart range: the whole history")
            }
        }

        /// The earliest date shown, or `nil` for the whole history.
        var cutoff: Date? {
            let calendar = Calendar.current
            switch self {
            case .month: return calendar.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: Date())
            case .year: return calendar.date(byAdding: .year, value: -1, to: Date())
            case .all: return nil
            }
        }
    }

    /// Every point in the chosen range, oldest first.
    private var points: [RoutineMeasurement] {
        let cutoff = range.cutoff
        return (routine.measurements ?? [])
            .filter { cutoff == nil || $0.date >= cutoff! }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        let points = points
        let highlighted = highlightedPoint(in: points)

        VStack(alignment: .leading, spacing: 12) {
            summary(for: highlighted, in: points)

            if points.isEmpty {
                Text("No numbers recorded in this period.", comment: "Shown in the value chart when its range has no points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                chart(points: points, highlighted: highlighted)
                    .frame(height: 180)
            }

            Picker(selection: $range) {
                ForEach(HistoryRange.allCases) { option in
                    option.title.tag(option)
                }
            } label: {
                Text("Range", comment: "Label for the value chart's time range picker")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Chart

    private func chart(points: [RoutineMeasurement], highlighted: RoutineMeasurement?) -> some View {
        let color = routine.color
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        // Breathing room above and below, and a floor to give a single point or
        // a flat line a visible scale.
        let padding = max((high - low) * 0.25, abs(high) * 0.05, 1)
        let lower = low - padding
        let upper = high + padding

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", lower),
                    yEnd: .value("Value", point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(color)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .symbolSize(point.persistentModelID == highlighted?.persistentModelID ? 110 : 36)
                .foregroundStyle(color)
            }

            if let selected = selectedPoint(in: points) {
                RuleMark(x: .value("Date", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
        .chartYScale(domain: lower...upper)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), anchor: .top)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(.secondary.opacity(0.4))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.snappy, value: range)
        .accessibilityLabel(Text("Value history", comment: "VoiceOver label for the value chart"))
        .accessibilityValue(accessibilitySummary(points: points))
    }

    // MARK: - Summary

    /// The point being described: the one under the finger, else the latest.
    private func highlightedPoint(in points: [RoutineMeasurement]) -> RoutineMeasurement? {
        selectedPoint(in: points) ?? points.last
    }

    private func selectedPoint(in points: [RoutineMeasurement]) -> RoutineMeasurement? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func summary(for point: RoutineMeasurement?, in points: [RoutineMeasurement]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let point {
                    Text(format(point.value))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(point.date.formatted(.dateTime.month(.abbreviated).day().year().locale(locale)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let first = points.first, let last = points.last, points.count > 1 {
                let change = last.value - first.value
                Label {
                    Text(format(abs(change)))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: change == 0 ? "equal" : (change > 0 ? "arrow.up.right" : "arrow.down.right"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(change == 0 ? Color.secondary : routine.color)
            }
        }
    }

    /// A number with the routine's unit, such as "22.5 kg".
    private func format(_ value: Double) -> String {
        let number = value.formatted(.number.locale(locale))
        let unit = routine.valueUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    private func accessibilitySummary(points: [RoutineMeasurement]) -> Text {
        guard let first = points.first, let last = points.last else {
            return Text("No numbers recorded", comment: "VoiceOver value for an empty value chart")
        }
        return Text(
            "From \(format(first.value)) to \(format(last.value)), \(points.count) entries",
            comment: "VoiceOver summary of the value chart: first value, latest value, number of entries"
        )
    }
}

#if DEBUG
#Preview {
    Form {
        Section {
            ValueHistoryChart(routine: PreviewData.sampleValueRoutine)
        }
    }
    .environment(DayTracker())
    .modelContainer(PreviewData.container)
}
#endif
