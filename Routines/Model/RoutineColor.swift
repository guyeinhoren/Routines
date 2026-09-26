//
//  RoutineColor.swift
//  Routines
//

import SwiftUI

/// The palette a routine's colour is chosen from.
///
/// The case's raw value is what gets persisted, so these names must not change
/// once a schema has shipped. Storing an identifier instead of a serialised
/// `Color` also keeps the routine looking right when the system switches between
/// light and dark appearance.
enum RoutineColor: String, CaseIterable, Identifiable, Sendable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown

    static let fallback = RoutineColor.blue

    /// Resolves a persisted identifier, falling back to a usable colour rather
    /// than failing when an unknown value arrives from a newer app version.
    init(identifier: String) {
        self = RoutineColor(rawValue: identifier) ?? .fallback
    }

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .mint: "Mint"
        case .teal: "Teal"
        case .cyan: "Cyan"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .brown: "Brown"
        }
    }
}
