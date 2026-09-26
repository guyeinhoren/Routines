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

    /// Anchors for the initial scroll position.
    private enum Anchor: Hashable {
        case routines
    }

    private var routines: [Routine] {
        guard let list else { return allRoutines }
        return allRoutines.filter { $0.belongs(to: list) }
    }

    private var tint: Color {
        list?.color ?? .accentColor
    }

    private var title: Text {
        if let list {
            Text(list.name)
        } else {
            Text("All", comment: "The entry covering every routine")
        }
    }

    var body: some View {
        content
            .navigationTitle(title)
            .toolbar { toolbarContent }
            .sheet(item: $detailRoutine) { routine in
                // A pane rising from the bottom, with its own navigation so
                // Edit pushes inside the pane instead of stacking sheets.
                NavigationStack {
                    RoutineDetailView(routine: routine)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isAddingRoutine) {
                NavigationStack {
                    RoutineEditorView(target: .new, defaultList: list)
                }
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
        ScrollViewReader { proxy in
            List {
                // Sits above everything and is scrolled past on arrival, so
                // it's there when you reach for it and out of the way when
                // you just want to tick a routine off.
                Section {
                    ActivityHeatmap(routines: routines, tint: tint)
                } header: {
                    Text("Activity", comment: "Header above the activity heatmap")
                        .textCase(nil)
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
                        .id(Anchor.routines)
                }
            }
            // A single uniform background rather than inset cards, so the
            // squares read as continuous columns down the screen.
            .listStyle(.plain)
            .task {
                proxy.scrollTo(Anchor.routines, anchor: .top)
            }
        }
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
