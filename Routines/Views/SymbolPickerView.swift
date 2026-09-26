//
//  SymbolPickerView.swift
//  Routines
//

import SwiftUI

/// A grid for choosing a routine's symbol.
struct SymbolPickerView: View {
    @Binding var symbolName: String
    let tint: Color

    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .title3) private var cellSize: CGFloat = 44

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: cellSize + 16), spacing: 12)], spacing: 12) {
                    ForEach(RoutineSymbolCatalog.all, id: \.self) { name in
                        cell(for: name)
                    }
                }
                .padding()
            }
            .navigationTitle(Text("Symbol", comment: "Title of the symbol picker"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", comment: "Dismisses the symbol picker")
                    }
                }
            }
        }
    }

    private func cell(for name: String) -> some View {
        let isSelected = name == symbolName

        return Button {
            symbolName = name
            dismiss()
        } label: {
            Image(systemName: name)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : tint)
                .frame(width: cellSize, height: cellSize)
                .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.fill.tertiary))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}
