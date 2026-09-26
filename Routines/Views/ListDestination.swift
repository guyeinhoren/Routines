//
//  ListDestination.swift
//  Routines
//

import SwiftData
import SwiftUI

/// A screen of routines the root can navigate to.
///
/// Navigation goes through values rather than closures so the open list can be
/// written to storage and reopened on the next launch. `Codable` for the same
/// reason: `PersistentIdentifier` survives relaunches, a model object doesn't.
enum ListDestination: Hashable, Codable {
    case all
    case list(PersistentIdentifier)
}

/// Resolves a destination to its screen.
struct ListDestinationView: View {
    let destination: ListDestination

    @Query private var lists: [RoutineList]

    var body: some View {
        switch destination {
        case .all:
            RoutineListView(list: nil)
        case .list(let id):
            if let list = lists.first(where: { $0.persistentModelID == id }) {
                RoutineListView(list: list)
            } else {
                // Reachable if the list was deleted on another device while it
                // was open here.
                ContentUnavailableView {
                    Label {
                        Text("List Not Found", comment: "Shown when the list being viewed no longer exists")
                    } icon: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
}
