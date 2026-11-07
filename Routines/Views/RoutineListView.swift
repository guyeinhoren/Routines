//
//  RoutineListView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// The routines of one list, or of everything when `list` is `nil`.
///
/// All groups its routines under their lists, the way All does in Reminders,
/// with each list's name in its colour above its routines.
struct RoutineListView: View {
    /// The list being shown. `nil` means All.
    let list: RoutineList?

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(DayTracker.self) private var dayTracker

    /// `createdAt` breaks ties. With `sortIndex` alone, two routines that share
    /// an index have no defined order, so any write to the store could re-fetch
    /// them the other way round and appear to shuffle the list.
    @Query(sort: [SortDescriptor(\Routine.sortIndex), SortDescriptor(\Routine.createdAt)])
    private var allRoutines: [Routine]

    @Query(sort: [SortDescriptor(\RoutineList.sortIndex), SortDescriptor(\RoutineList.createdAt)])
    private var lists: [RoutineList]

    @State private var isAddingRoutine = false
    @State private var detailRoutine: Routine?
    @State private var routinePendingDeletion: Routine?
    @State private var isConfirmingDeletion = false

    /// Whether the list is in edit mode, where tapping a routine selects it.
    /// Kept as plain state rather than the system's `EditMode`: the list's own
    /// selection didn't respond to taps on these rows, so the rows draw and
    /// toggle their selection themselves.
    @State private var isEditingRoutines = false

    /// The routines picked in edit mode, in the order they were picked, which
    /// the bottom bar's actions apply to and which a drag moves together.
    @State private var selection: [PersistentIdentifier] = []

    #if os(iOS)
    /// Each visible row's frame, for the two-finger selection to hit-test.
    @State private var rowFrames = RowFrames()

    /// The two-finger selection under way: the rows in order, the one it
    /// began on, whether it's selecting or deselecting, and the selection
    /// from before it began.
    @State private var rangeSelection: (
        ids: [PersistentIdentifier],
        anchor: Int,
        isSelecting: Bool,
        baseline: [PersistentIdentifier]
    )?
    #endif
    @State private var isConfirmingSelectionDeletion = false

    /// Whether the activity graph is showing. Starts hidden and is toggled from
    /// the toolbar.
    @State private var isActivityRevealed = false

    /// The first day of an earlier week picked in the activity graph, whose
    /// history the rows show instead of this week's. `nil` means this week.
    ///
    /// Deliberately short-lived: it clears when the app leaves the foreground,
    /// when a routine is tapped, and when the list is left, so the screen is
    /// never found showing an old week without having just asked for it.
    @State private var selectedWeekStart: Date?

    /// The week the rows and the weekday header show.
    private var displayedWeek: [Date] {
        guard let selectedWeekStart else { return dayTracker.week }
        return WeekPlanner.week(containing: selectedWeekStart)
    }

    private func returnToCurrentWeek() {
        guard selectedWeekStart != nil else { return }
        withAnimation(.snappy) {
            selectedWeekStart = nil
        }
    }

    /// The routines as they're grouped on screen: a single untitled section
    /// for a list, or one per list in All — in the lists' own order, empty
    /// ones left out — followed by any routines that belong to no list.
    ///
    /// A function rather than a computed property, and called once per
    /// `body`: the screen, the graph and the header all read the same
    /// sections, and recomputing them for each was repeated work.
    private func makeSections() -> [RoutineSection] {
        if let list {
            let members = allRoutines.filter { $0.belongs(to: list) }
            return [RoutineSection(id: list.persistentModelID, title: nil, color: list.color, routines: members)]
        }

        var byList: [PersistentIdentifier: [Routine]] = [:]
        var unassigned: [Routine] = []
        for routine in allRoutines {
            if let owner = routine.list {
                byList[owner.persistentModelID, default: []].append(routine)
            } else {
                unassigned.append(routine)
            }
        }

        var result: [RoutineSection] = lists.compactMap { list in
            guard !list.isSmart, let members = byList[list.persistentModelID] else { return nil }
            return RoutineSection(id: list.persistentModelID, title: Text(list.name), color: list.color, routines: members)
        }
        if !unassigned.isEmpty {
            result.append(RoutineSection(
                id: nil,
                title: Text("No List", comment: "Section in All for routines that belong to no list"),
                color: .gray,
                routines: unassigned
            ))
        }
        return result
    }

    /// Lists a routine can be moved into. Smart lists gather by tag, so they
    /// have no members to move into.
    private var assignableLists: [RoutineList] {
        lists.filter { !$0.isSmart }
    }

    private var isEditing: Bool {
        #if os(macOS)
        false
        #else
        isEditingRoutines
        #endif
    }

    /// iPhone reorders only in edit mode, where an always-on drag would
    /// otherwise compete with the row's own taps. The Mac drags directly.
    private var allowsReordering: Bool {
        #if os(macOS)
        true
        #else
        isEditing
        #endif
    }

    private var tint: Color {
        list?.color ?? .accentColor
    }

    /// This screen as a navigation value, for the Live Activity to reopen.
    private var destination: ListDestination {
        list.map { .list($0.persistentModelID) } ?? .all
    }

    #if os(macOS)
    /// The list's name in its colour, with the count opposite — the heading
    /// Mac Reminders puts at the top of a list instead of a window title.
    private func macHeader(count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            title
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(count, format: .number)
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
        let sections = makeSections()
        let routineCount = sections.reduce(0) { $0 + $1.routines.count }

        content(sections: sections, routineCount: routineCount)
            .navigationTitle(title)
            .toolbar { toolbarContent(isEmpty: routineCount == 0) }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { returnToCurrentWeek() }
            }
            .onChange(of: isActivityRevealed) { _, isRevealed in
                // With the graph hidden there's nothing to say which week the
                // rows are showing, so they go back to this one.
                if !isRevealed { returnToCurrentWeek() }
            }
            .onChange(of: isEditing) { _, editing in
                if !editing { selection.removeAll() }
            }
            .onDisappear {
                selectedWeekStart = nil
            }
            #if !os(macOS)
            .sheet(item: $detailRoutine) { routine in
                // Straight into the editor: there's no read-only stage first.
                NavigationStack {
                    RoutineEditorView(target: .existing(routine))
                }
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
            .confirmationDialog(
                Text("Delete Selected Routines?", comment: "Title of the confirmation for deleting the routines selected in edit mode"),
                isPresented: $isConfirmingSelectionDeletion,
                titleVisibility: .visible
            ) {
                Button(role: .destructive, action: deleteSelection) {
                    Text("Delete", comment: "Confirms deletion")
                }
            } message: {
                Text(
                    "Their recorded history will be deleted as well. This cannot be undone.",
                    comment: "Explanation in the confirmation for deleting several routines"
                )
            }
    }

    @ViewBuilder private func content(sections: [RoutineSection], routineCount: Int) -> some View {
        if routineCount == 0 {
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
            routineList(sections: sections, routineCount: routineCount)
        }
    }

    private func routineList(sections: [RoutineSection], routineCount: Int) -> some View {
        let week = displayedWeek
        let weekKeys = week.map { DayKey($0) }

        return List {
            #if os(macOS)
            macHeader(count: routineCount)
            #endif

            // Absent from the list until revealed, rather than present and
            // scrolled past. Scrolling a list to a position programmatically
            // depends on the rows having been laid out first, which made the
            // graph flash into view before the scroll caught up. Leaving the
            // row out entirely has no such timing to get wrong.
            if isActivityRevealed {
                Section {
                    ActivityHeatmap(sections: sections, tint: tint, selectedWeekStart: $selectedWeekStart)
                }
                .listRowSeparator(.hidden)
            }

            ForEach(sections.enumerated(), id: \.element.id) { index, section in
                Section {
                    ForEach(section.routines) { routine in
                        row(for: routine, week: weekKeys)
                    }
                    // Dragging a selection moves every selected routine at
                    // once, and in All a drop in another list's section moves
                    // the routines into that list.
                    .reorderable(collectionID: section.id)
                } header: {
                    VStack(spacing: 6) {
                        if index == 0, let selectedWeekStart {
                            pastWeekBanner(startingOn: selectedWeekStart)
                        }
                        WeekdayHeader(
                            week: week,
                            today: dayTracker.today,
                            title: section.title,
                            titleColor: section.color
                        )
                    }
                    .textCase(nil)
                }
            }
        }
        .reorderContainer(for: RoutineTransfer.self, in: PersistentIdentifier?.self, isEnabled: allowsReordering) { difference in
            applyReorder(difference)
        }
        // Lets a drag leave the list, so routines can be dropped onto another
        // list on the main screen. Off outside edit mode on iPhone, where a
        // long press shouldn't lift the row away from its own taps.
        .dragContainer(for: RoutineTransfer.self) { (ids: [PersistentIdentifier]) in
            allowsReordering ? ids.map(RoutineTransfer.init(id:)) : []
        }
        // Dragging a selected routine carries the rest of the selection with it.
        .dragContainerSelection(selection)
        #if os(iOS)
        .gesture(
            TwoFingerSelectionGesture(
                isEnabled: isEditing,
                onBegan: beginRangeSelection(at:),
                onChanged: extendRangeSelection(to:),
                onEnded: endRangeSelection
            )
        )
        #endif
        // A single uniform background rather than inset cards, so the
        // squares read as continuous columns down the screen.
        .listStyle(.plain)
        .animation(.snappy, value: isActivityRevealed)
    }

    private func row(for routine: Routine, week: [DayKey]) -> some View {
        RoutineRow(
            routine: routine,
            week: week,
            today: dayTracker.today,
            isShowingPastWeek: selectedWeekStart != nil,
            onReturnToCurrentWeek: returnToCurrentWeek,
            onOpenDetail: {
                returnToCurrentWeek()
                detailRoutine = routine
            },
            destination: destination
        )
        // While editing, a tap selects the row rather than recording a
        // repetition or opening the routine.
        .allowsHitTesting(!isEditing)
        .selectableInEditMode(
            isEditing: isEditing,
            isSelected: selection.contains(routine.persistentModelID),
            tint: tint
        ) {
            toggleSelection(of: routine)
        }
        #if os(iOS)
        // Where the row sits on screen, for the two-finger selection. Kept
        // out of view state so scrolling doesn't redraw the list, and dropped
        // when the row scrolls away so a stale frame can't match a new row.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            rowFrames.frames[routine.persistentModelID] = frame
        }
        .onDisappear {
            rowFrames.frames[routine.persistentModelID] = nil
        }
        #endif
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
        #if os(macOS)
        // A floating popover beside the routine, as Reminders and Calendar
        // show an item's details on the Mac. Clicking elsewhere closes it and
        // keeps the changes.
        .popover(isPresented: isShowingDetail(for: routine)) {
            NavigationStack {
                RoutineEditorView(target: .existing(routine), savesOnClose: true) {
                    detailRoutine = nil
                }
            }
            .frame(width: 360, height: 640)
        }
        #endif
    }

    #if os(macOS)
    private func isShowingDetail(for routine: Routine) -> Binding<Bool> {
        Binding {
            detailRoutine?.persistentModelID == routine.persistentModelID
        } set: { isShowing in
            if !isShowing, detailRoutine?.persistentModelID == routine.persistentModelID {
                detailRoutine = nil
            }
        }
    }
    #endif

    /// Says which week the rows are showing when it isn't this one, with a way
    /// straight back.
    private func pastWeekBanner(startingOn start: Date) -> some View {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start

        return HStack {
            Text((start..<end).formatted(.interval.month(.abbreviated).day().locale(locale)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Spacer()

            Button {
                returnToCurrentWeek()
            } label: {
                Text("This Week", comment: "Button that returns the routine rows to the current week")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private func toolbarContent(isEmpty: Bool) -> some ToolbarContent {
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

        #if os(macOS)
        // Reminders on the Mac keeps its add button in the window toolbar.
        ToolbarItem(placement: .primaryAction) {
            addButton
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.snappy) {
                    isEditingRoutines.toggle()
                }
            } label: {
                if isEditing {
                    Text("Done", comment: "Ends edit mode in a list")
                } else {
                    Text("Edit", comment: "Starts edit mode in a list")
                }
            }
            .disabled(isEmpty && !isEditing)
        }

        if isEditing {
            ToolbarItem(placement: .bottomBar) {
                moveSelectionMenu
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    isConfirmingSelectionDeletion = true
                } label: {
                    Label {
                        Text("Delete", comment: "Deletes the routines selected in edit mode")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                .disabled(selection.isEmpty)
            }
        } else {
            // Floating at the foot of the screen, where Reminders puts its
            // add button.
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                addButton
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            }
        }
        #endif
    }

    private var addButton: some View {
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

    /// Moves every selected routine into the chosen list at once.
    private var moveSelectionMenu: some View {
        Menu {
            ForEach(assignableLists) { destination in
                Button {
                    moveSelection(to: destination)
                } label: {
                    Label {
                        Text(destination.name)
                    } icon: {
                        Image(systemName: destination.symbolName)
                    }
                }
            }

            Divider()

            Button {
                moveSelection(to: nil)
            } label: {
                Text("No List", comment: "Section in All for routines that belong to no list")
            }
        } label: {
            Label {
                Text("Move to List", comment: "Moves the routines selected in edit mode into another list")
            } icon: {
                Image(systemName: "folder")
            }
        }
        .disabled(selection.isEmpty)
    }

    // MARK: - Actions

    /// Applies a drag: the moved routines leave wherever they were and land at
    /// the drop position, then `sortIndex` is rewritten across the whole store
    /// so the new order survives a relaunch. In All, landing in another list's
    /// section moves the routines into that list.
    private func applyReorder(_ difference: ReorderDifference<PersistentIdentifier, PersistentIdentifier?>) {
        let moving = Set(difference.sources)
        guard !moving.isEmpty else { return }

        let byID = Dictionary(allRoutines.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        let moved = difference.sources.compactMap { byID[$0] }

        var arranged = makeSections().map { (id: $0.id, routines: $0.routines) }
        for index in arranged.indices {
            arranged[index].routines.removeAll { moving.contains($0.persistentModelID) }
        }
        guard let target = arranged.firstIndex(where: { $0.id == difference.destination.collectionID }) else { return }

        switch difference.destination.position {
        case .before(let id):
            let index = arranged[target].routines.firstIndex { $0.persistentModelID == id }
                ?? arranged[target].routines.endIndex
            arranged[target].routines.insert(contentsOf: moved, at: index)
        case .end:
            arranged[target].routines.append(contentsOf: moved)
        }

        // Only All's sections are lists; inside one list, every section is
        // that same list (or a smart list, which has no members to move into).
        if list == nil {
            let destination = assignableLists.first { $0.persistentModelID == difference.destination.collectionID }
            for routine in moved where routine.list?.persistentModelID != destination?.persistentModelID {
                routine.list = destination
            }
        }

        RoutineStore.applyOrder(arranged.flatMap { $0.routines.map(\.persistentModelID) }, within: allRoutines)
    }

    #if os(iOS)
    /// The id of the row under `point`, matched on height alone so the
    /// fingers can wander sideways.
    private func rowID(at point: CGPoint) -> PersistentIdentifier? {
        rowFrames.frames.first { $0.value.minY <= point.y && point.y < $0.value.maxY }?.key
    }

    /// Starting on an unselected row selects the rows the fingers pass over;
    /// starting on a selected one deselects them, as in Reminders.
    private func beginRangeSelection(at point: CGPoint) {
        // The order of the rows is taken once for the whole gesture rather
        // than on every movement of the fingers.
        let ids = makeSections().flatMap { $0.routines.map(\.persistentModelID) }
        guard let id = rowID(at: point), let anchor = ids.firstIndex(of: id) else { return }
        rangeSelection = (ids, anchor, !selection.contains(id), selection)
        extendRangeSelection(to: point)
    }

    private func extendRangeSelection(to point: CGPoint) {
        guard let rangeSelection,
              let id = rowID(at: point),
              let current = rangeSelection.ids.firstIndex(of: id)
        else { return }

        let span = rangeSelection.ids[min(rangeSelection.anchor, current)...max(rangeSelection.anchor, current)]
        // In the order the fingers reach them, so a drag carries them that way.
        let reached = rangeSelection.anchor <= current ? Array(span) : span.reversed()
        let baseline = rangeSelection.baseline

        let updated: [PersistentIdentifier]
        if rangeSelection.isSelecting {
            let alreadySelected = Set(baseline)
            updated = baseline + reached.filter { !alreadySelected.contains($0) }
        } else {
            let passedOver = Set(span)
            updated = baseline.filter { !passedOver.contains($0) }
        }
        // Moving within one row would otherwise rewrite an identical selection
        // and redraw the list for nothing.
        if updated != selection { selection = updated }
    }

    private func endRangeSelection() {
        rangeSelection = nil
    }
    #endif

    private func toggleSelection(of routine: Routine) {
        let id = routine.persistentModelID
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
    }

    private var selectedRoutines: [Routine] {
        allRoutines.filter { selection.contains($0.persistentModelID) }
    }

    private func moveSelection(to destination: RoutineList?) {
        withAnimation {
            for routine in selectedRoutines {
                routine.list = destination
            }
        }
        selection.removeAll()
    }

    private func deleteSelection() {
        withAnimation {
            for routine in selectedRoutines {
                RoutineStore.delete(routine, in: context)
            }
        }
        selection.removeAll()
    }

    private func delete(_ routine: Routine) {
        withAnimation {
            RoutineStore.delete(routine, in: context)
        }
        routinePendingDeletion = nil
    }
}

#if os(iOS)
/// Row frames held by reference, so recording them as the list scrolls
/// doesn't invalidate the view that owns them.
private final class RowFrames {
    var frames: [PersistentIdentifier: CGRect] = [:]
}
#endif

private extension View {
    /// In edit mode, puts a selection circle before the row and makes the
    /// whole row a tap target that toggles it, as rows do in Reminders.
    func selectableInEditMode(
        isEditing: Bool,
        isSelected: Bool,
        tint: Color,
        toggle: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            self
        }
        .contentShape(.rect)
        .gesture(TapGesture().onEnded(toggle), isEnabled: isEditing)
        .accessibilityAddTraits(isEditing ? (isSelected ? [.isButton, .isSelected] : .isButton) : [])
    }
}

/// A group of routines as the list screen shows them, and the colour the
/// activity graph draws them in.
struct RoutineSection: Identifiable {
    /// The list the routines belong to, or `nil` for routines in no list.
    let id: PersistentIdentifier?

    /// The list's name, shown above its routines in All. `nil` inside a list,
    /// where the screen's own title already says it.
    let title: Text?

    let color: Color
    let routines: [Routine]
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
