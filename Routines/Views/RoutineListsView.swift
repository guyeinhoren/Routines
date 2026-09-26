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
    /// The destination showing beside the sidebar on the Mac, so the matching
    /// row or tile can be highlighted. Always `nil` on iPhone, where lists are
    /// pushed rather than shown alongside.
    @Binding var selection: ListDestination?

    /// Opens a list — pushing it on iPhone, selecting it on the Mac.
    let open: (ListDestination) -> Void

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
        container
            .navigationTitle(Text("Routines", comment: "Main screen title"))
            .overlay {
                if lists.isEmpty, routines.isEmpty {
                    emptyState
                }
            }
            .toolbar {
                // The Mac keeps "Add List" at the foot of the sidebar instead,
                // where Reminders puts it.
                #if !os(macOS)
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
                #endif
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

    /// A selectable sidebar on the Mac; a plain grouped list on iPhone, where
    /// rows push rather than select.
    @ViewBuilder private var container: some View {
        #if os(macOS)
        List(selection: $selection) {
            listContent
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addListButton
        }
        #else
        List {
            listContent
        }
        #endif
    }

    #if os(macOS)
    private var addListButton: some View {
        Button {
            editorTarget = .new
        } label: {
            Label {
                Text("Add List", comment: "Sidebar button that creates a list")
            } icon: {
                Image(systemName: "plus.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    #endif

    private var emptyState: some View {
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

    @ViewBuilder private var listContent: some View {
            Section {
                tileGrid
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

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

    // MARK: - Tiles

    /// All, followed by every pinned list, two to a row.
    ///
    /// A plain `Grid` rather than `LazyVGrid`. A lazy grid sizes itself from the
    /// width it's offered, while a Mac sidebar row sizes itself from its
    /// content; inside a sidebar the two kept re-measuring each other until
    /// AppKit gave up and crashed the app. There are only ever a few tiles, so
    /// laziness buys nothing here.
    private var tileGrid: some View {
        let tiles: [RoutineList?] = [nil] + pinnedLists.map(Optional.some)
        let rows = stride(from: 0, to: tiles.count, by: 2).map { Array(tiles[$0..<min($0 + 2, tiles.count)]) }

        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                GridRow {
                    ForEach(rows[rowIndex].indices, id: \.self) { column in
                        tile(for: rows[rowIndex][column])
                    }
                    // An odd tile out still takes only half the width.
                    if rows[rowIndex].count == 1 {
                        Color.clear
                            .gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
        #if os(macOS)
        // A sidebar row has no insets of its own here, so the tiles would
        // otherwise run to the sidebar's edges.
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        #endif
        .animation(.snappy, value: pinnedLists.map(\.persistentModelID))
    }

    /// One tile: All when `list` is `nil`, otherwise that pinned list.
    @ViewBuilder private func tile(for list: RoutineList?) -> some View {
        if let list {
            let destination = ListDestination.list(list.persistentModelID)
            tileButton(to: destination) {
                ListTile(
                    title: Text(list.name),
                    symbolName: list.symbolName,
                    tint: list.color,
                    count: list.routineCount,
                    isSelected: selection == destination
                )
            }
            .contextMenu {
                listActions(for: list)
            }
        } else {
            tileButton(to: .all) {
                ListTile(
                    title: Text("All", comment: "The entry covering every routine"),
                    symbolName: "tray.full.fill",
                    tint: .gray,
                    count: routines.count,
                    isSelected: selection == .all
                )
            }
        }
    }

    /// Tiles open their list directly. Several `NavigationLink`s sharing one
    /// list row would all respond to a tap on any of them; plain buttons each
    /// keep their own hit area.
    private func tileButton(to destination: ListDestination, @ViewBuilder label: () -> some View) -> some View {
        Button {
            open(destination)
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    /// Mac sidebars use smaller symbols than an iPhone list, as Reminders does.
    private var rowSymbolSize: CGFloat {
        #if os(macOS)
        22
        #else
        28
        #endif
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
                ListSymbol(symbolName: list.symbolName, tint: list.color, size: rowSymbolSize)
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
    var glyph: Color = .white

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)

            Image(systemName: symbolName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(glyph)
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

    /// Whether this tile's list is the one showing beside the sidebar. Mac
    /// Reminders fills a selected tile with its colour; iPhone never selects.
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Inverted when selected, so the symbol stays visible against a
                // background of its own colour.
                ListSymbol(
                    symbolName: symbolName,
                    tint: isSelected ? .white : tint,
                    size: symbolSize,
                    glyph: isSelected ? tint : .white
                )

                Spacer(minLength: 4)

                Text(count, format: .number)
                    .font(countFont)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            }

            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .lineLimit(1)
        }
        .padding(tilePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? tint : tileBackground,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    // A Mac sidebar is narrower than an iPhone screen, so its tiles are
    // tighter — close to the proportions of Reminders' own.
    #if os(macOS)
    private let symbolSize: CGFloat = 26
    private let tilePadding: CGFloat = 8
    private let countFont = Font.title2.weight(.bold)
    #else
    private let symbolSize: CGFloat = 32
    private let tilePadding: CGFloat = 12
    private let countFont = Font.title.weight(.bold)
    #endif

    /// The colour a grouped list gives its rows, so a tile reads as a cell
    /// lifted off the background rather than a separate kind of control.
    private var tileBackground: Color {
        #if os(macOS)
        // The Mac's control background matches the window, so a tile drawn
        // with it vanishes; a faint tint of the text colour stays visible in
        // both appearances.
        Color.primary.opacity(0.06)
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
