//
//  RoutineDetailView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A routine's details, read-only, reached by tapping its name on the main
/// screen.
///
/// Follows the shape Contacts uses: everything is presented for reading, and
/// Edit opens the editor rather than turning every row into a control. The
/// caller supplies the navigation, so this can be pushed inside the pane it is
/// presented in.
struct RoutineDetailView: View {
    let routine: Routine

    @Environment(\.dismiss) private var dismiss
    @Environment(DayTracker.self) private var dayTracker

    @State private var isEditing = false
    @State private var timerRoutine: Routine?

    var body: some View {
        Form {
            headerSection

            if routine.imageData != nil || routine.hasDetails {
                descriptionSection
            }

            scheduleSection

            if let list = routine.list {
                listSection(for: list)
            }

            historySection
        }
        .formStyle(.grouped)
        .navigationTitle(routine.name)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditing = true
                } label: {
                    Text("Edit", comment: "Opens the editor from the detail view")
                }
            }
        }
        .navigationDestination(isPresented: $isEditing) {
            // Deleting leaves nothing to show here, so close the whole pane
            // rather than popping back to a routine that no longer exists.
            RoutineEditorView(target: .existing(routine)) {
                dismiss()
            }
        }
        .fullScreenPresentation(item: $timerRoutine) { routine in
            RoutineTimerScreen(routine: routine)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                RoutineSymbolBadge(routine: routine, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.title3.weight(.semibold))

                    todayDescription
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)

            if routine.isTimed {
                Button {
                    timerRoutine = routine
                } label: {
                    Label {
                        Text("Start Timer", comment: "Starts the routine's timer from the detail view")
                    } icon: {
                        Image(systemName: "play.fill")
                    }
                }
            }
        }
    }

    /// The photo heads the description rather than standing in for the symbol,
    /// so it gets the full width of the pane.
    private var descriptionSection: some View {
        Section {
            if let imageData = routine.imageData {
                RoutinePhotoBanner(imageData: imageData)
                    .listRowInsets(EdgeInsets())
            }

            if routine.hasDetails {
                Text(routine.richDetails)
            }
        } header: {
            Text("Description", comment: "Label for the routine description field")
        }
    }

    private var scheduleSection: some View {
        Section {
            LabeledContent {
                Text(routine.dailyTarget, format: .number)
            } label: {
                Text("Repetitions per Day", comment: "How many times a day the routine is performed")
            }

            if routine.isTimed {
                LabeledContent {
                    Text(durationDescription)
                        .monospacedDigit()
                } label: {
                    Text("Duration", comment: "Resulting total duration")
                }
            }
        } header: {
            Text("Schedule", comment: "Section header for repetitions and duration")
        }
    }

    private func listSection(for list: RoutineList) -> some View {
        Section {
            Label {
                Text(list.name)
            } icon: {
                Image(systemName: list.symbolName)
                    .foregroundStyle(list.color)
            }
        } header: {
            Text("List", comment: "Row that chooses the routine's list")
        }
    }

    /// Read-only here. Filling a day in after the fact is an edit, so it is
    /// only possible from the editor.
    private var historySection: some View {
        Section {
            RoutineHistoryCalendar(routine: routine)
        } header: {
            Text("History", comment: "Section header for the history calendar")
        }
    }

    // MARK: - Descriptions

    private var todayDescription: Text {
        let done = routine.completedCount(on: dayTracker.today)
        let target = routine.dailyTarget

        if target > 1 {
            return Text("\(done) of \(target) done today", comment: "Accessibility value for today's progress")
        }
        return done > 0
            ? Text("Done today", comment: "Accessibility value when today is complete")
            : Text("Not done today", comment: "Accessibility value when today is incomplete")
    }

    private var durationDescription: String {
        let pattern: Duration.TimeFormatStyle.Pattern = routine.durationSeconds >= 3600
            ? .hourMinuteSecond
            : .minuteSecond
        return Duration.seconds(routine.durationSeconds).formatted(.time(pattern: pattern))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        RoutineDetailView(routine: PreviewData.sampleRoutine)
    }
    .environment(DayTracker())
    .modelContainer(PreviewData.container)
}

// The width of the Mac inspector column, where the view actually lives there.
#Preview("Inspector Width") {
    NavigationStack {
        RoutineDetailView(routine: PreviewData.sampleRoutine)
    }
    .environment(DayTracker())
    .modelContainer(PreviewData.container)
    .environment(\.locale, Locale(identifier: "he_IL"))
    .environment(\.layoutDirection, .rightToLeft)
    .frame(width: 340, height: 720)
}
#endif
