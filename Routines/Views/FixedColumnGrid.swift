//
//  FixedColumnGrid.swift
//  Routines
//

import SwiftUI

/// Lays items out in rows of a fixed number of columns, using an eager `Grid`.
///
/// Use this instead of `LazyVGrid` anywhere inside a `List` or `Form` row. A
/// lazy grid sizes itself from the width it's offered, while a row on the Mac
/// sizes itself from its content; put together, each keeps re-measuring the
/// other. AppKit either throws (as the sidebar did) or the app hangs (as the
/// routine inspector did). The grids here hold a month of days or a dozen
/// colours at most, so laziness gains nothing.
struct FixedColumnGrid<Item, Cell: View>: View {
    let items: [Item]
    let columns: Int
    var spacing: CGFloat = 4
    @ViewBuilder let cell: (Item) -> Cell

    private var rowCount: Int {
        (items.count + columns - 1) / columns
    }

    var body: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < items.count {
                            cell(items[index])
                        } else {
                            // Pads a short last row so its cells keep the
                            // same width as the rows above.
                            Color.clear
                                .gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }
}
