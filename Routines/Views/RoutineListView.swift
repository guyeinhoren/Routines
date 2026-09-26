//
//  RoutineListView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// The routines of one list, or of everything when `list` is `nil`.
struct RoutineListView: View {
    /// The list being shown. `nil` means All, which has no workout of its own
    /// because a workout covers one list.
    let list: RoutineList?

    @Environment(\.modelContext) private var context
    @Environment(DayTracker.self) private var dayTracker
    @Environment(WorkoutController.self) private var workout

    /// `createdAt` breaks ties. With `sortIndex` alone, two routines that share
    /// an index have no defined order, so any write to the store could re-fetch
    /// them the other way round and appear to shuffle the list.
    @Query(sort: [SortDescriptor(\Routine.sortIndex), SortDescriptor(\Routine.createdAt)])
    private var allRoutines: [Routine]

    @State private var isAddingRoutine = false
    @State private var detailRoutine: Routine?
    @State private var timerRoutine: Routine?
    @State private var routinePendingDeletion: Routine?
    @State private var isConfirmingDeletion = false

    /// Whether the activity graph is showing. Starts hidden and is toggled from
    /// the toolbar.
    @State private var isActivityRevealed = false

    private var routines: [Routine] {
        guard let list else { return allRoutines }
        return allRoutines.filter { $0.belongs(to: list) }
    }

    private var tint: Color {
        list?.color ?? .accentColor
    }

    #if os(macOS)
    /// The list's name in its colour, with the count opposite — the heading
    /// Mac Reminders puts at the top of a list instead of a window title.
    private var macHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            title
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(routines.count, format: .number)
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()
        }
        // All belongs to no list, so it takes the ordinary text colour.
        .foregroundStyle(list?.color ?? .primary)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .listRowSeparator(.hidden)
    }
    #endif

    private var title: Text {
        if let list {
            Text(list.name)
        } else {
            Text("All", comment: "The entry covering every routine")
        }
    }

    var body: some View {
        mainContent
            .navigationTitle(title)
            .toolbar { toolbarContent }
            #if !os(macOS)
            .sheet(item: $detailRoutine) { routine in
                // A pane rising from the bottom, with its own navigation so
                // Edit pushes inside the pane instead of stacking sheets.
                NavigationStack {
                    RoutineDetailView(routine: routine)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            #endif
            .sheet(isPresented: $isAddingRoutine) {
                NavigationStack {
                    RoutineEditorView(target: .new, defaultList: list)
                }
                #if os(macOS)
                .frame(minWidth: 460, idealWidth: 500, minHeight: 560, idealHeight: 680)
                #endif
            }
            .fullScreenPresentation(item: $timerRoutine) { routine in
                RoutineTimerScreen(routine: routine)
            }
            .confirmationDialog(
                Text("Delete Routine?", comment: "Title of the delete confirmation"),
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible,
                presenting: routinePendingDeletion
            ) { routine in
                Button(role: .destructive) {
                    delete(routine)
                } label: {
                    Text("Delete “\(routine.name)”", comment: "Confirm deleting a named routine")
                }
            } message: { _ in
                Text(
                    "Its recorded history will be deleted as well. This cannot be undone.",
                    comment: "Explanation in the delete confirmation"
                )
            }
    }

    #if os(macOS)
    /// The list, with the selected routine's details in a panel beside it.
    ///
    /// This is a plain `HStack`, not the system `.inspector` modifier. On this
    /// SDK, `.inspector` crashes AppKit reliably the moment it animates from
    /// closed to open — reproduced with an inspector holding nothing but a
    /// `Text`, with no `RoutineListsView` or `RoutineListView` code involved,
    /// so it isn't something in this app to fix. Opening it already-open
    /// never crashed, which is what pinned it to the open transition. A
    /// hand-built panel gets the same look without going through that code
    /// path at all.
    private var mainContent: some View {
        HStack(spacing: 0) {
            content

            if let detailRoutine {
                Divider()

                NavigationStack {
                    RoutineDetailView(routine: detailRoutine)
                }
                .id(detailRoutine.persistentModelID)
                .frame(width: 340)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.default, value: detailRoutine?.persistentModelID)
    }
    #else
    private var mainContent: some View { content }
    #endif

    @ViewBuilder private var content: some View {
        if routines.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("No Routines", comment: "Empty state title")
                } icon: {
                    Image(systemName: "checklist")
                }
            } description: {
                Text("Add a routine to start tracking it day by day.", comment: "Empty state description")
            } actions: {
                Button {
                    isAddingRoutine = true
                } label: {
                    Text("Add Routine", comment: "Empty state action")
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            routineList
        }
    }

    private var routineList: some View {
        List {
            #if os(macOS)
            macHeader
            #endif

            // Absent from the list until revealed, rather than present and
            // scrolled past. Scrolling a list to a position programmatically
            // depends on the rows having been laid out first, which made the
            // graph flash into view before the scroll caught up. Leaving the
            // row out entirely has no such timing to get wrong.
            if isActivityRevealed {
                Section {
                    ActivityHeatmap(routines: routines, tint: tint)
                }
                .listRowSeparator(.hidden)
            }

            if let session = workout.session {
                WorkoutBanner(session: session)
            }

            Section {
                ForEach(routines) { routine in
                    RoutineRow(
                        routine: routine,
                        week: dayTracker.week,
                        today: dayTracker.today,
                        onOpenDetail: { detailRoutine = routine },
                        onStartTimer: { timerRoutine = routine }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            routinePendingDeletion = routine
                            isConfirmingDeletion = true
                        } label: {
                            Label {
                                Text("Delete", comment: "Swipe action")
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                // Reordering happens through edit mode rather than an
                // always-on drag, which competed with the row's own taps.
                .onMove(perform: move)
            } header: {
                WeekdayHeader(week: dayTracker.week, today: dayTracker.today)
                    .textCase(nil)
            }
        }
        // A single uniform background rather than inset cards, so the
        // squares read as continuous columns down the screen.
        .listStyle(.plain)
        .animation(.snappy, value: isActivityRevealed)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        // A workout covers one list, so All has nothing to start.
        if let list {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                workoutControl(for: list)
            }
            #else
            ToolbarItem(placement: .topBarLeading) {
                workoutControl(for: list)
            }
            #endif
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.snappy) {
                    isActivityRevealed.toggle()
                }
            } label: {
                Label {
                    Text("Activity", comment: "Header above the activity heatmap")
                } icon: {
                    Image(systemName: "chart.bar.xaxis")
                }
            }
            .accessibilityAddTraits(isActivityRevealed ? [.isButton, .isSelected] : [.isButton])
        }

        // macOS lists reorder by dragging directly, so they need no edit mode.
        #if !os(macOS)
        ToolbarItem(placement: .primaryAction) {
            EditButton()
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            Button {
                isAddingRoutine = true
            } label: {
                Label {
                    Text("Add Routine", comment: "Toolbar button that creates a routine")
                } icon: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ViewBuilder private func workoutControl(for list: RoutineList) -> some View {
        if workout.isRunning(for: list) {
            Button {
                Task { await workout.end(in: context) }
            } label: {
                Label {
                    Text("End Workout", comment: "Toolbar button that finishes the workout")
                } icon: {
                    Image(systemName: "stop.circle")
                }
            }
        } else {
            Button {
                withAnimation(.snappy) {
                    workout.start(list: list, in: context)
                }
            } label: {
                Label {
                    Text("Start Workout", comment: "Toolbar button that starts a workout")
                } icon: {
                    Image(systemName: "play.circle")
                }
            }
            // Only one workout at a time; another list already has one running.
            .disabled(workout.isRunning)
        }
    }

    // MARK: - Actions

    /// Applies a move made in edit mode, then rewrites `sortIndex` across the
    /// whole store so the new order survives a relaunch.
    private func move(from source: IndexSet, to destination: Int) {
        var ordered = routines
        ordered.move(fromOffsets: source, toOffset: destination)
        RoutineStore.applyOrder(ordered.map(\.persistentModelID), within: allRoutines)
    }

    private func delete(_ routine: Routine) {
        withAnimation {
            RoutineStore.delete(routine, in: context)
        }
        routinePendingDeletion = nil
    }
}

#if DEBUG
#Preview("English") {
    PreviewData.listScreen
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Hebrew") {
    PreviewData.listScreen
        .environment(\.locale, Locale(identifier: "he_IL"))
        .environment(\.layoutDirection, .rightToLeft)
}
#endif
