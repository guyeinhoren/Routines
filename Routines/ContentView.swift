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

    #if os(macOS)
    @State private var selection: ListDestination?
    #else
    @State private var path: [ListDestination] = []
    #endif

    /// The list that was open, archived. `AppStorage` rather than
    /// `SceneStorage`: iOS throws scene storage away when the app is swiped
    /// out of the app switcher, which is exactly the relaunch this is for.
    @AppStorage(SettingsKey.lastOpenedList) private var lastOpenedList: Data?

    @AppStorage(SettingsKey.hasSeenWelcome) private var hasSeenWelcome = false
    @AppStorage(SettingsKey.showWelcomeAgain) private var showWelcomeAgain = false
    @State private var isShowingWelcome = false

    var body: some View {
        navigation
            .environment(dayTracker)
            .task {
                restoreLastOpenedList()
                presentWelcomeIfDue()
            }
            .onOpenURL { url in
                // A tap on the Live Activity opens the list it was started from.
                guard let destination = ListDestination(url: url) else { return }
                open(destination)
            }
            .onChange(of: scenePhase) { _, phase in
                // The clock may have moved a long way while the app was away, so
                // re-check which day's square should be the editable one.
                guard phase == .active else { return }
                dayTracker.refresh()
                #if os(iOS)
                // Switched off in Settings while the app was away.
                RoutineStatusActivity.endIfDisabled()
                #endif
                // On iPhone the welcome screen is asked for from the Settings
                // app, so the request is found on the way back in.
                presentWelcomeIfDue()
            }
            .onChange(of: showWelcomeAgain) { _, requested in
                // The Mac asks from its Settings window while the app runs.
                if requested { presentWelcomeIfDue() }
            }
            .sheet(isPresented: $isShowingWelcome) {
                WelcomeView {
                    isShowingWelcome = false
                }
                // Continue is the way out, as on Apple's own welcome screens.
                .interactiveDismissDisabled()
                .onDisappear {
                    hasSeenWelcome = true
                    showWelcomeAgain = false
                }
            }
    }

    private func presentWelcomeIfDue() {
        guard !hasSeenWelcome || showWelcomeAgain, !isShowingWelcome else { return }
        isShowingWelcome = true
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

    private func open(_ destination: ListDestination) {
        #if os(macOS)
        selection = destination
        #else
        path = [destination]
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

#if DEBUG
#Preview("Hebrew") {
    ContentView()
        .modelContainer(PreviewData.container)
        .environment(\.locale, Locale(identifier: "he_IL"))
        .environment(\.layoutDirection, .rightToLeft)
        .frame(width: 980, height: 600)
}
#endif
