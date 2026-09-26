//
//  RoutineRowMetrics.swift
//  Routines
//

import SwiftUI

/// Shared geometry for the main screen's columns of day squares.
///
/// The header of weekday initials and every routine row take their widths from
/// here. That is what keeps the columns lined up down the screen — in
/// particular the play slot, which is reserved whether or not a routine is
/// timed so the squares never shift between rows.
enum RoutineRowMetrics {
    static let squareSpacing: CGFloat = 3
    static let columnSpacing: CGFloat = 10
    static let playSlotWidth: CGFloat = 30

    /// The base length of one square. Rows and the header both scale this with
    /// the same text style, so they stay in step under Dynamic Type.
    static let squareSide: CGFloat = 26
}
