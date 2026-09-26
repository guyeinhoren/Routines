//
//  RoutineEditorView.swift
//  Routines
//

import PhotosUI
import SwiftData
import SwiftUI

/// Shows and edits every detail of a routine. Reached through a routine's
/// detail pane, and also used to create a new one.
struct RoutineEditorView: View {
    let target: RoutineEditorTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]

    @Query(sort: [SortDescriptor(\RoutineList.sortIndex), SortDescriptor(\RoutineList.createdAt)])
    private var lists: [RoutineList]

    // Declared without an initial value because `init` assigns it; the `@State`
    // macro treats a declaration-site value as the one that wins.
    @State private var draft: RoutineDraft

    @State private var isShowingSymbolPicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var isConfirmingDeletion = false

    /// Passing a selection binding is what lets the system offer its text
    /// formatting controls for the rich-text description.
    @State private var detailsSelection = AttributedTextSelection()

    /// Called after the routine is deleted, so a detail view that presented the
    /// editor can pop instead of being left pointing at a deleted object.
    private let onDelete: (() -> Void)?

    /// Pre-selects the list a new routine is being created from, so adding one
    /// inside a list doesn't need the list picked again.
    init(
        target: RoutineEditorTarget,
        defaultList: RoutineList? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.target = target
        self.onDelete = onDelete
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

    // The caller supplies the navigation — the editor is pushed inside the
    // detail pane when editing, and wrapped in a stack when adding.
    var body: some View {
        Form {
            identitySection
            detailsSection
            appearanceSection
            scheduleSection
            listSection

            if case .existing(let routine) = target {
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
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Dismisses the editor without saving")
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    if isNew {
                        Text("Add", comment: "Saves a new routine")
                    } else {
                        Text("Done", comment: "Saves changes to a routine")
                    }
                }
                .disabled(!draft.isSaveable)
            }
        }
        .sheet(isPresented: $isShowingSymbolPicker) {
            SymbolPickerView(symbolName: $draft.symbolName, tint: draft.color.color)
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

    // MARK: - Sections

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

    private var appearanceSection: some View {
        Section {
            Button {
                isShowingSymbolPicker = true
            } label: {
                LabeledContent {
                    Image(systemName: draft.symbolName)
                        .foregroundStyle(draft.color.color)
                } label: {
                    Text("Symbol", comment: "Row that opens the symbol picker")
                }
            }
            .buttonStyle(.plain)

            colorRow
        } header: {
            Text("Appearance", comment: "Section header for symbol, colour and photo")
        } footer: {
            Text(
                "The symbol and colour identify the routine. A photo goes at the head of the description.",
                comment: "Explains the roles of the symbol and the photo"
            )
        }
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color", comment: "Label above the colour swatches")

            ColorSwatchGrid(selection: $draft.color)
        }
        .padding(.vertical, 4)
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

    /// A routine belongs to exactly one list, so this is a single choice rather
    /// than the multi-select the old tags needed.
    private var listSection: some View {
        Section {
            Picker(selection: $draft.listID) {
                Text("None", comment: "The option for a routine that belongs to no list")
                    .tag(PersistentIdentifier?.none)

                ForEach(lists) { list in
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
        } header: {
            Text("List", comment: "Row that chooses the routine's list")
        } footer: {
            Text(
                "Workouts are started from a list, and cover every routine in it.",
                comment: "Explains the relationship between lists and workouts"
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
        dismiss()
    }

    private func deleteRoutine() {
        if case .existing(let routine) = target {
            RoutineStore.delete(routine, in: context)
        }
        dismiss()
        onDelete?()
    }
}

#if DEBUG
// The editor takes its navigation from whatever presents it, so the previews
// supply a stack the way the detail pane and the add sheet do.
#Preview("Edit") {
    NavigationStack {
        RoutineEditorView(target: .existing(PreviewData.sampleRoutine))
    }
    .modelContainer(PreviewData.container)
}

#Preview("New") {
    NavigationStack {
        RoutineEditorView(target: .new)
    }
    .modelContainer(PreviewData.container)
}
#endif
