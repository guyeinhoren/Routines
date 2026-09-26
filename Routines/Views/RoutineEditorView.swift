//
//  RoutineEditorView.swift
//  Routines
//

import PhotosUI
import SwiftData
import SwiftUI

/// Shows and edits every detail of a routine. Reached from the info button or
/// the symbol on the main screen, and also used to create a new routine.
struct RoutineEditorView: View {
    let target: RoutineEditorTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]
    @Query(sort: \RoutineTag.name) private var tags: [RoutineTag]

    // Declared without an initial value because `init` assigns it; the `@State`
    // macro treats a declaration-site value as the one that wins.
    @State private var draft: RoutineDraft

    @State private var isShowingSymbolPicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var newTagName = ""
    @State private var isConfirmingDeletion = false

    init(target: RoutineEditorTarget) {
        self.target = target
        switch target {
        case .new:
            draft = RoutineDraft()
        case .existing(let routine):
            draft = RoutineDraft(routine: routine)
        }
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                appearanceSection
                scheduleSection
                tagsSection

                if case .existing = target {
                    deleteSection
                }
            }
            .navigationTitle(navigationTitle)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Dismisses the editor without saving")
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
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 540)
        #endif
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

                VStack(alignment: .leading, spacing: 4) {
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

            TextField(
                text: $draft.details,
                prompt: Text("Description", comment: "Placeholder for the routine description"),
                axis: .vertical
            ) {
                Text("Description", comment: "Label for the routine description field")
            }
            .lineLimit(2...6)
        }
    }

    private var previewBadge: some View {
        Button {
            isShowingSymbolPicker = true
        } label: {
            ZStack {
                if let data = draft.imageData, let image = Image(data: data) {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    draft.color.color.opacity(0.18)
                    Image(systemName: draft.symbolName)
                        .font(.title2)
                        .foregroundStyle(draft.color.color)
                }
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
        } header: {
            Text("Appearance", comment: "Section header for symbol, colour and photo")
        } footer: {
            Text(
                "A photo replaces the symbol on the main screen.",
                comment: "Explains that the photo takes precedence over the symbol"
            )
        }
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color", comment: "Label above the colour swatches")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                ForEach(RoutineColor.allCases) { option in
                    Button {
                        draft.color = option
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if option == draft.color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(option.displayName))
                    .accessibilityAddTraits(option == draft.color ? [.isButton, .isSelected] : [.isButton])
                }
            }
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
                Stepper(value: $draft.durationMinutes, in: 0...240) {
                    LabeledContent {
                        Text(draft.durationMinutes, format: .number)
                    } label: {
                        Text("Minutes", comment: "Duration minutes stepper")
                    }
                }

                Stepper(value: $draft.durationSeconds, in: 0...55, step: 5) {
                    LabeledContent {
                        Text(draft.durationSeconds, format: .number)
                    } label: {
                        Text("Seconds", comment: "Duration seconds stepper")
                    }
                }

                LabeledContent {
                    Text(draft.durationDescription)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Duration", comment: "Resulting total duration")
                }
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

    private var tagsSection: some View {
        Section {
            ForEach(tags) { tag in
                Button {
                    toggle(tag)
                } label: {
                    LabeledContent {
                        if draft.tagIDs.contains(tag.persistentModelID) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    } label: {
                        Label {
                            Text(tag.name)
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(tag.color)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    draft.tagIDs.contains(tag.persistentModelID) ? [.isButton, .isSelected] : [.isButton]
                )
            }

            HStack {
                TextField(
                    text: $newTagName,
                    prompt: Text("New Tag", comment: "Placeholder for creating a tag")
                ) {
                    Text("New Tag", comment: "Label for the new tag field")
                }
                .onSubmit(addTag)

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(Text("Add Tag", comment: "VoiceOver label for the add tag button"))
            }
        } header: {
            Text("Tags", comment: "Section header for tags")
        } footer: {
            Text(
                "Workouts are started from a tag, and cover every routine that carries it.",
                comment: "Explains the relationship between tags and workouts"
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

    private func toggle(_ tag: RoutineTag) {
        let id = tag.persistentModelID
        if draft.tagIDs.contains(id) {
            draft.tagIDs.remove(id)
        } else {
            draft.tagIDs.insert(id)
        }
    }

    /// Creates the tag straight away and selects it.
    ///
    /// Tags are shared between routines, so a new one is worth keeping even if
    /// this edit is then cancelled.
    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            draft.tagIDs.insert(existing.persistentModelID)
        } else {
            let tag = RoutineTag(name: name, colorIdentifier: draft.color.rawValue)
            context.insert(tag)
            draft.tagIDs.insert(tag.persistentModelID)
        }

        newTagName = ""
    }

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
            draft.apply(to: routine, availableTags: tags)
        case .existing(let routine):
            draft.apply(to: routine, availableTags: tags)
        }
        dismiss()
    }

    private func deleteRoutine() {
        if case .existing(let routine) = target {
            RoutineStore.delete(routine, in: context)
        }
        dismiss()
    }
}
