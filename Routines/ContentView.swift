//
//  ContentView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// Root of the app's window: owns the shared controllers and the navigation,
/// and reopens whichever list was on screen when the app was last left.
///
/// The Mac gets a sidebar with the open list beside it, the layout Reminders
/// uses there. iPhone and iPad push lists onto a stack.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    @State private var dayTracker = DayTracker()
    @State private var workout = WorkoutController()

    #if os(macOS)
    @State private var selection: ListDestination?
    #else
    @State private var path: [ListDestination] = []
    #endif

    /// The list that was open, archived. `AppStorage` rather than
    /// `SceneStorage`: iOS throws scene storage away when the app is swiped
    /// out of the app switcher, which is exactly the relaunch this is for.
    @AppStorage(SettingsKey.lastOpenedList) private var lastOpenedList: Data?

    var body: some View {
        navigation
            .environment(dayTracker)
            .environment(workout)
            .task {
                restoreLastOpenedList()
            }
            .onChange(of: scenePhase) { _, phase in
                // The clock may have moved a long way while the app was away, so
                // re-check which day's square should be the editable one.
                guard phase == .active else { return }
                dayTracker.refresh()
            }
    }

    @ViewBuilder private var navigation: some View {
        #if os(macOS)
        NavigationSplitView {
            RoutineListsView(selection: $selection) { selection = $0 }
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 340)
        } detail: {
            if let selection {
                // Its own stack so a list's detail pane can push the editor.
                NavigationStack {
                    ListDestinationView(destination: selection)
                }
                .id(selection)
            } else {
                ContentUnavailableView {
                    Label {
                        Text("No List Selected", comment: "Shown on the Mac before a list is chosen in the sidebar")
                    } icon: {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
        }
        .onChange(of: selection) { _, newSelection in
            remember(newSelection)
        }
        #else
        NavigationStack(path: $path) {
            RoutineListsView(selection: .constant(nil)) { path.append($0) }
                .navigationDestination(for: ListDestination.self) { destination in
                    ListDestinationView(destination: destination)
                }
        }
        .onChange(of: path) { _, newPath in
            // Going back to the root clears it, so the next launch opens on
            // whatever was actually on screen.
            remember(newPath.last)
        }
        #endif
    }

    private func remember(_ destination: ListDestination?) {
        lastOpenedList = destination.flatMap { try? JSONEncoder().encode($0) }
    }

    private func restoreLastOpenedList() {
        guard let lastOpenedList,
              let destination = try? JSONDecoder().decode(ListDestination.self, from: lastOpenedList)
        else {
            #if os(macOS)
            // A Mac window with nothing selected is an empty pane, so start on
            // All rather than on a placeholder.
            if selection == nil { selection = .all }
            #endif
            return
        }

        // A list deleted since — here or on another device — isn't worth
        // reopening onto an empty screen.
        if case .list(let id) = destination {
            let lists = (try? context.fetch(FetchDescriptor<RoutineList>())) ?? []
            guard lists.contains(where: { $0.persistentModelID == id }) else {
                self.lastOpenedList = nil
                #if os(macOS)
                if selection == nil { selection = .all }
                #endif
                return
            }
        }

        #if os(macOS)
        if selection == nil { selection = destination }
        #else
        if path.isEmpty { path = [destination] }
        #endif
    }
}
