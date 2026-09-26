//
//  ColorSwatchGrid.swift
//  Routines
//

import SwiftUI

/// The palette as a grid of swatches, with the chosen one checked.
///
/// Shared by the routine and list editors. Six to a row puts the twelve colours
/// in two even rows at every width.
struct ColorSwatchGrid: View {
    @Binding var selection: RoutineColor

    var body: some View {
        // Eager, not lazy: this sits in a form row. See `FixedColumnGrid`.
        FixedColumnGrid(items: RoutineColor.allCases, columns: 6, spacing: 10) { option in
            Button {
                selection = option
            } label: {
                Circle()
                    .fill(option.color)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if option == selection {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(option.displayName))
            .accessibilityAddTraits(option == selection ? [.isButton, .isSelected] : [.isButton])
        }
        .padding(.vertical, 4)
    }
}
