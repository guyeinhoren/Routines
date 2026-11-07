//
//  RoutineTransfer.swift
//  Routines
//

import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

/// A dragged routine, carried by its identifier so it can be dropped onto a
/// list on the main screen and moved there.
///
/// Only the identifier travels — never a copy of the routine — so the drop
/// moves the routine itself, and nothing meaningful leaves the app if it's
/// dropped somewhere else.
nonisolated struct RoutineTransfer: Codable, Identifiable, Transferable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .routine)
    }
}

extension UTType {
    /// Declared under `UTExportedTypeDeclarations` in Info.plist.
    nonisolated static let routine = UTType(exportedAs: "GuyEinhoren.Routines.routine")
}
