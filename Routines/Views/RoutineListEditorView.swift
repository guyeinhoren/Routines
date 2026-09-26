//
//  RoutineListEditorView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// Creates or renames a list, and picks the symbol and colour that identify it
/// on the root screen and in its Live Activity.
struct RoutineListEditorView: View {
    /// What the editor is working on.
    enum Target: Identifiable {
        case new
        case existing(RoutineList)

        var id: PersistentIdentifier? {
            switch self {
            case .new: nil
            case .existing(let list): list.persistentModelID
            }
        }
    }

    let target: Target

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \RoutineList.sortIndex) private var lists: [RoutineList]

    // No values at the declarations because `init` assigns them.
    @State private var name: String
    @State private var symbolName: String
    @State private var color: RoutineColor

    @State private var isShowingSymbolPicker = false

    init(target: Target) {
        self.target = target
        switch target {
        case .new:
            name = ""
            symbolName = "list.bullet"
            color = .fallback
        case .existing(let list):
            name = list.name
            symbolName = list.symbolName
            color = RoutineColor(identifier: list.colorIdentifier)
        }
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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
                            prompt: Text("List Name", comment: "Placeholder for a list's name")
                        ) {
                            Text("List Name", comment: "Label for a list's name field")
                        }
                        .font(.headline)
                        #if !os(macOS)
                        .textInputAutocapitalization(.words)
                        #endif
                    }
                }

                Section {
                    colorGrid
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
                    .disabled(trimmedName.isEmpty)
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

    private var navigationTitle: Text {
        if isNew {
            Text("New List", comment: "List editor title when creating")
        } else {
            Text("List", comment: "List editor title when editing")
        }
    }

    private var colorGrid: some View {
        ColorSwatchGrid(selection: $color)
    }

    private func save() {
        switch target {
        case .new:
            let list = RoutineList(
                name: trimmedName,
                symbolName: symbolName,
                colorIdentifier: color.rawValue,
                sortIndex: RoutineStore.nextSortIndex(after: lists)
            )
            context.insert(list)
        case .existing(let list):
            list.name = trimmedName
            list.symbolName = symbolName
            list.colorIdentifier = color.rawValue
        }
        dismiss()
    }
}
