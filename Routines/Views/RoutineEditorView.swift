//
//  RoutineEditorView.swift
//  Routines
//

import PhotosUI
import SwiftData
import SwiftUI

/// Shows and edits every detail of a routine. Opened straight from a routine's
/// name on the main screen, and also used to create a new one.
///
/// There's no separate read-only view in front of it: everything it would show
/// is here, along with the one action it offered that isn't an edit — starting
/// the timer.
struct RoutineEditorView: View {
    let target: RoutineEditorTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(DayTracker.self) private var dayTracker

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]

    @Query(sort: [SortDescriptor(\RoutineList.sortIndex), SortDescriptor(\RoutineList.createdAt)])
    private var lists: [RoutineList]

    // Declared without an initial value because `init` assigns it; the `@State`
    // macro treats a declaration-site value as the one that wins.
    @State private var draft: RoutineDraft

    @State private var isShowingSymbolPicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var isConfirmingDeletion = false
    @State private var timerRoutine: Routine?

    /// Passing a selection binding is what lets the system offer its text
    /// formatting controls for the rich-text description.
    @State private var detailsSelection = AttributedTextSelection()

    /// Called instead of `dismiss` when the editor closes — after saving,
    /// cancelling or deleting. The Mac shows the editor in a panel beside the
    /// list rather than presenting it, and a panel can't be dismissed.
    private let onFinish: (() -> Void)?

    /// Pre-selects the list a new routine is being created from, so adding one
    /// inside a list doesn't need the list picked again.
    init(
        target: RoutineEditorTarget,
        defaultList: RoutineList? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.target = target
        self.onFinish = onFinish
        switch target {
        case .new:
            draft = RoutineDraft(defaultList: defaultList)
        case .existing(let routine):
            draft = RoutineDraft(routine: routine)
        }
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    private var existingRoutine: Routine? {
        if case .existing(let routine) = target { routine } else { nil }
    }

    /// Lists a routine can be a member of. Smart lists gather by tag, so they
    /// aren't something to pick here.
    private var assignableLists: [RoutineList] {
        lists.filter { !$0.isSmart }
    }

    /// In the Mac's side panel the window toolbar belongs to the list, so the
    /// editor's own buttons go at the foot of the panel instead.
    private var usesInlineActions: Bool {
        #if os(macOS)
        onFinish != nil
        #else
        false
        #endif
    }

    // The caller supplies the navigation — a stack inside the sheet on iPhone,
    // or inside the side panel on the Mac.
    var body: some View {
        Form {
            identitySection
            detailsSection
            scheduleSection
            organizationSection

            if let routine = existingRoutine {
                historySection(for: routine)
                deleteSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(navigationTitle)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !usesInlineActions {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if usesInlineActions {
                inlineActions
            }
        }
        .sheet(isPresented: $isShowingSymbolPicker) {
            SymbolPickerView(symbolName: $draft.symbolName, tint: draft.color.color)
        }
        .fullScreenPresentation(item: $timerRoutine) { routine in
            RoutineTimerScreen(routine: routine)
        }
        .onChange(of: photoSelection) { _, selection in
            Task { await loadPhoto(from: selection) }
        }
    }

    private var navigationTitle: Text {
        if isNew {
            Text("New Routine", comment: "Editor title when creating")
        } else {
            Text("Routine", comment: "Editor title when editing")
        }
    }

    // MARK: - Actions bar

    private var cancelButton: some View {
        Button(action: finish) {
            Text("Cancel", comment: "Dismisses the editor without saving")
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            if isNew {
                Text("Add", comment: "Saves a new routine")
            } else {
                Text("Done", comment: "Saves changes to a routine")
            }
        }
        .disabled(!draft.isSaveable)
    }

    private var inlineActions: some View {
        HStack {
            cancelButton
                .keyboardShortcut(.cancelAction)
            Spacer()
            saveButton
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Sections

    /// The symbol, the name and the colour together, since between them they
    /// are what identifies the routine on every screen. Tapping the symbol
    /// changes it, so there's no separate row for that.
    private var identitySection: some View {
        Section {
            HStack(spacing: 14) {
                previewBadge

                TextField(
                    text: $draft.name,
                    prompt: Text("Name", comment: "Placeholder for the routine name")
                ) {
                    Text("Name", comment: "Label for the routine name field")
                }
                .font(.headline)
                #if !os(macOS)
                .textInputAutocapitalization(.sentences)
                #endif
            }

            ColorSwatchGrid(selection: $draft.color)

            if let routine = existingRoutine, routine.isTimed {
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
        } footer: {
            if let routine = existingRoutine {
                todayDescription(for: routine)
            }
        }
    }

    /// The photo and the description, in that order: the photo heads the
    /// description rather than standing in for the symbol.
    private var detailsSection: some View {
        Section {
            if let data = draft.imageData {
                RoutinePhotoBanner(imageData: data)
                    .listRowInsets(EdgeInsets())
            }

            TextEditor(text: $draft.details, selection: $detailsSelection)
                // The full SwiftUI attribute scope, so the system's formatting
                // controls offer bold, italic, underline and the rest.
                .attributedTextFormattingDefinition(\.swiftUI)
                .frame(minHeight: 120)

            // After the text, so the description itself sits directly under the
            // section header rather than behind a photo control.
            photoControls
        } header: {
            Text("Description", comment: "Label for the routine description field")
        } footer: {
            Text(
                "Select text to make it bold, italic, underlined or coloured.",
                comment: "Explains how to format the description"
            )
        }
    }

    @ViewBuilder private var photoControls: some View {
        PhotosPicker(selection: $photoSelection, matching: .images) {
            if draft.imageData == nil {
                Text("Add Photo", comment: "Row that opens the photo picker")
            } else {
                Text("Replace Photo", comment: "Row that replaces the chosen photo")
            }
        }

        if draft.imageData != nil {
            Button(role: .destructive) {
                draft.imageData = nil
                photoSelection = nil
            } label: {
                Text("Remove Photo", comment: "Clears the routine's photo")
            }
        }
    }

    private var previewBadge: some View {
        Button {
            isShowingSymbolPicker = true
        } label: {
            ZStack {
                draft.color.color.opacity(0.18)

                Image(systemName: draft.symbolName)
                    .font(.title2)
                    .foregroundStyle(draft.color.color)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Choose Symbol", comment: "VoiceOver label for the symbol preview button"))
    }

    private var scheduleSection: some View {
        Section {
            Stepper(value: $draft.repetitionsPerDay, in: 1...20) {
                LabeledContent {
                    Text(draft.repetitionsPerDay, format: .number)
                } label: {
                    Text("Repetitions per Day", comment: "How many times a day the routine is performed")
                }
            }

            Toggle(isOn: $draft.isTimed) {
                Text("Timed", comment: "Switch that gives the routine a duration")
            }

            if draft.isTimed {
                DurationPicker(totalSeconds: $draft.durationSeconds)
            }
        } header: {
            Text("Schedule", comment: "Section header for repetitions and duration")
        } footer: {
            if draft.isTimed {
                Text(
                    "A timed routine gets a play button on the main screen.",
                    comment: "Explains what the Timed switch enables"
                )
            } else if draft.repetitionsPerDay > 1 {
                Text(
                    "The day square fills gradually as you record each repetition.",
                    comment: "Explains partial filling of a day square"
                )
            }
        }
    }

    /// The routine's one list, and its tag. A routine belongs to exactly one
    /// list; the tag is what lets smart lists gather it alongside routines
    /// from other lists.
    private var organizationSection: some View {
        Section {
            Picker(selection: $draft.listID) {
                Text("None", comment: "The option for a routine that belongs to no list")
                    .tag(PersistentIdentifier?.none)

                ForEach(assignableLists) { list in
                    Label {
                        Text(list.name)
                    } icon: {
                        Image(systemName: list.symbolName)
                            .foregroundStyle(list.color)
                    }
                    .tag(PersistentIdentifier?.some(list.persistentModelID))
                }
            } label: {
                Text("List", comment: "Row that chooses the routine's list")
            }

            TagField(tag: $draft.tag, suggestions: RoutineTag.all(in: routines))
        } header: {
            Text("List", comment: "Row that chooses the routine's list")
        } footer: {
            Text(
                "Workouts are started from a list. A tag gathers routines from any list into a smart list.",
                comment: "Explains lists and tags in the routine editor"
            )
        }
    }

    /// A month of recorded history, editable here so a day missed at the time
    /// can still be filled in.
    private func historySection(for routine: Routine) -> some View {
        Section {
            RoutineHistoryCalendar(routine: routine, isEditable: true)
        } header: {
            Text("History", comment: "Section header for the history calendar")
        } footer: {
            Text(
                "Tap a past day to record it now. Step back to see earlier months.",
                comment: "Explains the editable history calendar"
            )
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDeletion = true
            } label: {
                Text("Delete Routine", comment: "Deletes the routine being edited")
            }
            .confirmationDialog(
                Text("Delete Routine?", comment: "Title of the delete confirmation"),
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button(role: .destructive, action: deleteRoutine) {
                    Text("Delete", comment: "Confirms deletion")
                }
            } message: {
                Text(
                    "Its recorded history will be deleted as well. This cannot be undone.",
                    comment: "Explanation in the delete confirmation"
                )
            }
        }
    }

    /// Today's progress, as the detail view used to show under the name.
    private func todayDescription(for routine: Routine) -> Text {
        let done = routine.completedCount(on: dayTracker.today)
        let target = routine.dailyTarget

        if target > 1 {
            return Text("\(done) of \(target) done today", comment: "Accessibility value for today's progress")
        }
        return done > 0
            ? Text("Done today", comment: "Accessibility value when today is complete")
            : Text("Not done today", comment: "Accessibility value when today is incomplete")
    }

    // MARK: - Actions

    private func loadPhoto(from selection: PhotosPickerItem?) async {
        guard let selection else { return }
        guard let data = try? await selection.loadTransferable(type: Data.self) else { return }
        // Fall back to the original bytes if the image can't be re-encoded, so a
        // format ImageIO doesn't recognise still shows something.
        draft.imageData = data.downscaledImageData() ?? data
    }

    private func save() {
        switch target {
        case .new:
            let routine = Routine(sortIndex: RoutineStore.nextSortIndex(after: routines))
            context.insert(routine)
            draft.apply(to: routine, availableLists: lists)
        case .existing(let routine):
            draft.apply(to: routine, availableLists: lists)
        }
        finish()
    }

    private func deleteRoutine() {
        if let routine = existingRoutine {
            RoutineStore.delete(routine, in: context)
        }
        finish()
    }

    private func finish() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

#if DEBUG
// The editor takes its navigation from whatever presents it, so the previews
// supply a stack the way the sheet and the Mac panel do.
#Preview("Edit") {
    NavigationStack {
        RoutineEditorView(target: .existing(PreviewData.sampleRoutine))
    }
    .environment(DayTracker())
    .modelContainer(PreviewData.container)
}

#Preview("New") {
    NavigationStack {
        RoutineEditorView(target: .new)
    }
    .environment(DayTracker())
    .modelContainer(PreviewData.container)
}

// The width of the Mac panel, where the editor sits beside the list.
#Preview("Mac Panel Width") {
    NavigationStack {
        RoutineEditorView(target: .existing(PreviewData.sampleRoutine), onFinish: {})
    }
    .environment(DayTracker())
    .modelContainer(PreviewData.container)
    .environment(\.locale, Locale(identifier: "he_IL"))
    .environment(\.layoutDirection, .rightToLeft)
    .frame(width: 340, height: 720)
}
#endif
