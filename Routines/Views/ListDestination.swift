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

extension ListDestination {
    private static let urlScheme = "routines"

    /// A link that reopens this screen, which the Live Activity hands to the
    /// system so a tap on it lands on the list it came from.
    var url: URL? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = "list"
        components.queryItems = [URLQueryItem(name: "destination", value: data.base64EncodedString())]
        return components.url
    }

    init?(url: URL) {
        guard url.scheme == Self.urlScheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "destination" })?.value,
              let data = Data(base64Encoded: encoded),
              let destination = try? JSONDecoder().decode(ListDestination.self, from: data)
        else { return nil }
        self = destination
    }
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
