//
//  DurationPicker.swift
//  Routines
//

import SwiftUI

/// Picks a length of time the way the Clock app's timer does: scrolling wheels
/// with a fixed unit label beside each.
///
/// SwiftUI has no duration picker, so this composes three `Picker`s. The wheel
/// style only exists on iOS, iPadOS and watchOS, so the Mac gets menu pickers
/// instead — still a direct pick rather than nudging a value up and down.
///
/// The wheels always run hours, minutes then seconds from left to right, even in
/// a right-to-left layout. A duration is read like a clock face, and mirroring
/// it would put seconds where hours are expected.
struct DurationPicker: View {
    /// The whole duration. The three wheels are derived from it so the caller
    /// only ever deals with one number.
    @Binding var totalSeconds: Int

    private var hours: Int { totalSeconds / 3600 }
    private var minutes: Int { (totalSeconds % 3600) / 60 }
    private var seconds: Int { totalSeconds % 60 }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { hours },
            set: { totalSeconds = $0 * 3600 + minutes * 60 + seconds }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { minutes },
            set: { totalSeconds = hours * 3600 + $0 * 60 + seconds }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { seconds },
            set: { totalSeconds = hours * 3600 + minutes * 60 + $0 }
        )
    }

    var body: some View {
        wheels
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Duration", comment: "VoiceOver label for the duration picker"))
    }

    private var wheels: some View {
        #if os(macOS)
        HStack(spacing: 16) {
            menu(hoursBinding, range: 0...23, unit: hoursLabel)
            menu(minutesBinding, range: 0...59, unit: minutesLabel)
            menu(secondsBinding, range: 0...59, unit: secondsLabel)
        }
        #else
        HStack(spacing: 0) {
            wheel(hoursBinding, range: 0...23, unit: hoursLabel)
            wheel(minutesBinding, range: 0...59, unit: minutesLabel)
            wheel(secondsBinding, range: 0...59, unit: secondsLabel)
        }
        .frame(maxWidth: .infinity)
        #endif
    }

    // MARK: - Controls

    #if !os(macOS)
    /// One wheel and its unit. The label sits outside the picker so it stays
    /// put while the numbers scroll past it, as it does in the Clock app.
    private func wheel(_ value: Binding<Int>, range: ClosedRange<Int>, unit: Text) -> some View {
        HStack(spacing: 2) {
            Picker(selection: value) {
                ForEach(range, id: \.self) { number in
                    Text(number, format: .number).tag(number)
                }
            } label: {
                unit
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 58)
            .clipped()

            unit
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }
    #endif

    #if os(macOS)
    private func menu(_ value: Binding<Int>, range: ClosedRange<Int>, unit: Text) -> some View {
        Picker(selection: value) {
            ForEach(range, id: \.self) { number in
                Text(number, format: .number).tag(number)
            }
        } label: {
            unit
        }
        .pickerStyle(.menu)
        .fixedSize()
    }
    #endif

    // MARK: - Unit labels

    private var hoursLabel: Text {
        Text("hr", comment: "Short unit label beside the hours wheel of the duration picker")
    }

    private var minutesLabel: Text {
        Text("min", comment: "Short unit label beside the minutes wheel of the duration picker")
    }

    private var secondsLabel: Text {
        Text("sec", comment: "Short unit label beside the seconds wheel of the duration picker")
    }
}
