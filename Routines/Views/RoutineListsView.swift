//
//  RoutineListsView.swift
//  Routines
//

import SwiftData
import SwiftUI

/// The app's root screen: the lists a routine can belong to, plus All.
///
/// Laid out the way Reminders lays out its lists — tiles across the top for All
/// and anything pinned, then the remaining lists below. A long press on a list
/// pins or unpins it.
struct RoutineListsView: View {
    @Binding var path: [ListDestination]

    @Environment(\.modelContext) private var context
    @Environment(DayTracker.self) private var dayTracker
    @Environment(WorkoutController.self) private var workout

    @Query(sort: [SortDescriptor(\RoutineList.sortIndex), SortDescriptor(\RoutineList.createdAt)])
    private var lists: [RoutineList]

    @Query private var routines: [Routine]

    @State private var editorTarget: RoutineListEditorView.Target?
    @State private var listPendingDeletion: RoutineList?
    @State private var isConfirmingDeletion = false

    private var pinnedLists: [RoutineList] {
        lists.filter(\.isPinned)
    }

    private var unpinnedLists: [RoutineList] {
        lists.filter { !$0.isPinned }
    }

    /// Routines that ended up in no list — after the move from tags, or because
    /// one was added without picking a list. Surfaced so they can't get lost.
    private var unassignedCount: Int {
        routines.count { $0.list == nil }
    }

    var body: some View {
        List {
            Section {
                tileGrid
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if !unpinnedLists.isEmpty || unassignedCount > 0 {
                Section {
                    ForEach(unpinnedLists) { list in
                        NavigationLink(value: ListDestination.list(list.persistentModelID)) {
                            summaryRow(for: list)
                        }
                        .contextMenu {
                            listActions(for: list)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                confirmDeletion(of: list)
                            } label: {
                                Label {
                                    Text("Delete", comment: "Swipe action")
                                } icon: {
                                    Image(systemName: "trash")
                                }
                            }

                            Button {
                                editorTarget = .existing(list)
                            } label: {
                                Label {
                                    Text("Edit", comment: "Opens the editor from the detail view")
                                } icon: {
                                    Image(systemName: "pencil")
                                }
                            }
                            .tint(.gray)
                        }
                    }
                    .onMove(perform: moveUnpinned)
                } header: {
                    Text("My Lists", comment: "Header above the person's routine lists")
                } footer: {
                    if unassignedCount > 0 {
                        // Deliberately countless: a number here would need a
                        // plural rule in every language, and the exact figure
                        // adds nothing.
                        Text(
                            "Some routines aren't in a list yet. Open All to give them one.",
                            comment: "Footer pointing out routines with no list"
                        )
                    }
                }
            }
        }
        .navigationTitle(Text("Routines", comment: "Main screen title"))
        .overlay {
            if lists.isEmpty, routines.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Lists", comment: "Empty state title for lists")
                    } icon: {
                        Image(systemName: "list.bullet")
                    }
                } description: {
                    Text(
                        "Make a list for each kind of routine — strength, stretching, whatever you keep up.",
                        comment: "Empty state description for lists"
                    )
                } actions: {
                    Button {
                        editorTarget = .new
                    } label: {
                        Text("New List", comment: "List editor title when creating")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = .new
                } label: {
                    Label {
                        Text("New List", comment: "List editor title when creating")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            RoutineListEditorView(target: target)
        }
        .confirmationDialog(
            Text("Delete List?", comment: "Title of the list delete confirmation"),
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: listPendingDeletion
        ) { list in
            Button(role: .destructive) {
                delete(list)
            } label: {
                Text("Delete “\(list.name)”", comment: "Confirm deleting a named routine")
            }
        } message: { _ in
            Text(
                "Its routines are kept and stay available under All.",
                comment: "Reassures that deleting a list doesn't delete routines"
            )
        }
        .task {
            workout.restoreActiveSession(in: context)
            await dayTracker.run()
        }
    }

    // MARK: - Tiles

    /// All, followed by every pinned list, two to a row.
    private var tileGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            tileButton(to: .all) {
                ListTile(
                    title: Text("All", comment: "The entry covering every routine"),
                    symbolName: "tray.full.fill",
                    tint: .gray,
                    count: routines.count
                )
            }

            ForEach(pinnedLists) { list in
                tileButton(to: .list(list.persistentModelID)) {
                    ListTile(
                        title: Text(list.name),
                        symbolName: list.symbolName,
                        tint: list.color,
                        count: list.routineCount
                    )
                }
                .contextMenu {
                    listActions(for: list)
                }
            }
        }
        .animation(.snappy, value: pinnedLists.map(\.persistentModelID))
    }

    /// Tiles push onto the path directly. Several `NavigationLink`s sharing one
    /// list row would all respond to a tap on any of them; plain buttons each
    /// keep their own hit area.
    private func tileButton(to destination: ListDestination, @ViewBuilder label: () -> some View) -> some View {
        Button {
            path.append(destination)
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rows

    private func summaryRow(for list: RoutineList) -> some View {
        LabeledContent {
            Text(list.routineCount, format: .number)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } label: {
            Label {
                Text(list.name)
            } icon: {
                ListSymbol(symbolName: list.symbolName, tint: list.color, size: 28)
            }
        }
    }

    /// The long-press menu, shared by tiles and rows so a list offers the same
    /// actions wherever it sits.
    @ViewBuilder private func listActions(for list: RoutineList) -> some View {
        Button {
            withAnimation(.snappy) {
                list.isPinned.toggle()
            }
        } label: {
            if list.isPinned {
                Label {
                    Text("Unpin", comment: "Moves a pinned list back into My Lists")
                } icon: {
                    Image(systemName: "pin.slash")
                }
            } else {
                Label {
                    Text("Pin", comment: "Shows a list as a tile at the top of the main screen")
                } icon: {
                    Image(systemName: "pin")
                }
            }
        }

        Button {
            editorTarget = .existing(list)
        } label: {
            Label {
                Text("Edit", comment: "Opens the editor from the detail view")
            } icon: {
                Image(systemName: "pencil")
            }
        }

        Divider()

        Button(role: .destructive) {
            confirmDeletion(of: list)
        } label: {
            Label {
                Text("Delete", comment: "Swipe action")
            } icon: {
                Image(systemName: "trash")
            }
        }
    }

    // MARK: - Actions

    /// Reorders within My Lists. Pinned lists keep their place ahead of them,
    /// so the tiles aren't shuffled by a move made further down.
    private func moveUnpinned(from source: IndexSet, to destination: Int) {
        var reordered = unpinnedLists
        reordered.move(fromOffsets: source, toOffset: destination)
        RoutineStore.applyOrder(pinnedLists + reordered)
    }

    private func confirmDeletion(of list: RoutineList) {
        listPendingDeletion = list
        isConfirmingDeletion = true
    }

    private func delete(_ list: RoutineList) {
        withAnimation {
            RoutineStore.delete(list, in: context)
        }
        listPendingDeletion = nil
    }
}

/// A list's symbol in a filled circle of its colour.
private struct ListSymbol: View {
    let symbolName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)

            Image(systemName: symbolName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A tile at the top of the root screen, shaped like the ones Reminders uses
/// for its smart and pinned lists.
private struct ListTile: View {
    let title: Text
    let symbolName: String
    let tint: Color
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ListSymbol(symbolName: symbolName, tint: tint, size: 32)

                Spacer(minLength: 4)

                Text(count, format: .number)
                    .font(.title.weight(.bold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
            }

            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The colour a grouped list gives its rows, so a tile reads as a cell
    /// lifted off the background rather than a separate kind of control.
    private var tileBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

#if DEBUG
#Preview("English") {
    PreviewData.root
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Hebrew") {
    PreviewData.root
        .environment(\.locale, Locale(identifier: "he_IL"))
        .environment(\.layoutDirection, .rightToLeft)
}
#endif
