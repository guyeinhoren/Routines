//
//  RoutineListEditorView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// Creates or edits a list — ordinary or smart — and picks the symbol and
/// colour that identify it on the root screen and in its Live Activity.
struct RoutineListEditorView: View {
    /// What the editor is working on.
    enum Target: Identifiable {
        case new
        case newSmart
        case existing(RoutineList)

        var id: AnyHashable {
            switch self {
            case .new: "new"
            case .newSmart: "newSmart"
            case .existing(let list): list.persistentModelID
            }
        }
    }

    let target: Target

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \RoutineList.sortIndex) private var lists: [RoutineList]
    @Query private var routines: [Routine]

    // No values at the declarations because `init` assigns them.
    @State private var name: String
    @State private var symbolName: String
    @State private var color: RoutineColor
    @State private var tag: String

    @State private var isShowingSymbolPicker = false

    init(target: Target) {
        self.target = target
        switch target {
        case .new:
            name = ""
            symbolName = "list.bullet"
            color = .fallback
            tag = ""
        case .newSmart:
            name = ""
            symbolName = "number"
            color = .purple
            tag = ""
        case .existing(let list):
            name = list.name
            symbolName = list.symbolName
            color = RoutineColor(identifier: list.colorIdentifier)
            tag = list.smartTag ?? ""
        }
    }

    private var isNew: Bool {
        switch target {
        case .new, .newSmart: true
        case .existing: false
        }
    }

    private var isSmart: Bool {
        switch target {
        case .new: false
        case .newSmart: true
        case .existing(let list): list.isSmart
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A smart list gathers a single tag, so anything after a comma is
    /// dropped rather than producing a tag no routine could ever match.
    private var normalizedTag: String {
        RoutineTag.split(tag).first ?? ""
    }

    /// A smart list may go unnamed — it then takes its tag's name — but it
    /// can't go without a tag, which is the whole of what it shows.
    private var isSaveable: Bool {
        isSmart ? !normalizedTag.isEmpty : !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Button {
                            isShowingSymbolPicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.color)

                                Image(systemName: symbolName)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 52, height: 52)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Choose Symbol", comment: "VoiceOver label for the symbol preview button"))

                        TextField(
                            text: $name,
                            prompt: isSmart && !normalizedTag.isEmpty
                                ? Text(normalizedTag)
                                : Text("List Name", comment: "Placeholder for a list's name")
                        ) {
                            Text("List Name", comment: "Label for a list's name field")
                        }
                        .font(.headline)
                        #if !os(macOS)
                        .textInputAutocapitalization(.words)
                        #endif
                    }
                }

                if isSmart {
                    tagSection
                }

                Section {
                    ColorSwatchGrid(selection: $color)
                } header: {
                    Text("Color", comment: "Label above the colour swatches")
                }
            }
            .formStyle(.grouped)
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
                    Button(action: save) {
                        if isNew {
                            Text("Add", comment: "Saves a new routine")
                        } else {
                            Text("Done", comment: "Saves changes to a routine")
                        }
                    }
                    .disabled(!isSaveable)
                }
            }
            .sheet(isPresented: $isShowingSymbolPicker) {
                SymbolPickerView(symbolName: $symbolName, tint: color.color)
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 380)
        #endif
    }

    /// The tag a smart list gathers: typed, or picked from tags already in use.
    private var tagSection: some View {
        Section {
            TagField(tag: $tag, routines: routines)
        } header: {
            Text("Tag", comment: "Header above a routine's or smart list's tag")
        } footer: {
            Text(
                "Shows every routine with this tag, whichever list it's in.",
                comment: "Explains what a smart list shows"
            )
        }
    }

    private var navigationTitle: Text {
        switch target {
        case .new:
            Text("New List", comment: "List editor title when creating")
        case .newSmart:
            Text("New Smart List", comment: "List editor title when creating a smart list")
        case .existing(let list):
            list.isSmart
                ? Text("Smart List", comment: "List editor title when editing a smart list")
                : Text("List", comment: "List editor title when editing")
        }
    }

    private func save() {
        let finalName = trimmedName.isEmpty ? normalizedTag : trimmedName

        switch target {
        case .new, .newSmart:
            let list = RoutineList(
                name: finalName,
                symbolName: symbolName,
                colorIdentifier: color.rawValue,
                sortIndex: RoutineStore.nextSortIndex(after: lists)
            )
            if isSmart {
                list.smartTag = normalizedTag
            }
            context.insert(list)
        case .existing(let list):
            list.name = finalName
            list.symbolName = symbolName
            list.colorIdentifier = color.rawValue
            if list.isSmart {
                list.smartTag = normalizedTag
            }
        }
        dismiss()
    }
}

/// A tag typed freely, with the tags already in use one tap away.
///
/// Offering the existing tags matters more than it looks: a smart list only
/// gathers routines whose tag matches, so a typo quietly leaves a routine out.
///
/// With `allowsMultiple`, as for a routine, the text is a comma-separated set
/// of tags and picking a suggestion adds it to the set rather than replacing
/// what's there.
struct TagField: View {
    @Binding var tag: String

    /// The routines whose tags are offered. Passed whole, and turned into
    /// suggestions here, so the work happens only when this field redraws —
    /// not on every keystroke elsewhere in the editor that hosts it.
    let routines: [Routine]
    var allowsMultiple = false

    var body: some View {
        let suggestions = otherSuggestions

        HStack {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(
                text: $tag,
                prompt: allowsMultiple
                    ? Text("Tags, separated by commas", comment: "Placeholder for a routine's tags")
                    : Text("Tag", comment: "Placeholder for a tag")
            ) {
                Text("Tag", comment: "Header above a routine's or smart list's tag")
            }
            #if !os(macOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()

            if !suggestions.isEmpty {
                Menu {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            add(suggestion)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel(Text("Existing Tags", comment: "VoiceOver label for the menu of tags already in use"))
            }
        }
    }

    /// The tags in use other than the ones already entered.
    private var otherSuggestions: [String] {
        let entered = RoutineTag.split(tag)
        return RoutineTag.all(in: routines).filter { suggestion in
            !entered.contains { RoutineTag.matches($0, suggestion) }
        }
    }

    private func add(_ suggestion: String) {
        guard allowsMultiple else {
            tag = suggestion
            return
        }
        tag = RoutineTag.joined(RoutineTag.split(tag) + [suggestion])
    }
}
