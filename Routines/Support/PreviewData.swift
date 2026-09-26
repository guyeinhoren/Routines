//
//  PreviewData.swift
//  Routines
//

#if DEBUG
import SwiftData
import SwiftUI

/// A throwaway in-memory store with a few realistic lists and routines, so
/// previews show the screens as they actually look rather than empty states.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        // CloudKit is explicitly off: an in-memory preview store has nothing to
        // sync, and leaving it on makes previews wait on the account.
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: Routine.self, RoutineList.self, RoutineCompletion.self, WorkoutSession.self,
                configurations: configuration
            )
            seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to build the preview container: \(error)")
        }
    }()

    /// The root screen, wired up with the controllers it expects.
    static var root: some View {
        NavigationStack {
            RoutineListsView(selection: .constant(nil), open: { _ in })
        }
        .environment(DayTracker())
        .environment(WorkoutController())
        .modelContainer(container)
    }

    /// One list's routines, for previewing the routines screen directly.
    static var listScreen: some View {
        NavigationStack {
            RoutineListView(list: sampleList)
        }
        .environment(DayTracker())
        .environment(WorkoutController())
        .modelContainer(container)
    }

    static var sampleList: RoutineList? {
        var descriptor = FetchDescriptor<RoutineList>(sortBy: [SortDescriptor(\.sortIndex)])
        descriptor.fetchLimit = 1
        return (try? container.mainContext.fetch(descriptor))?.first
    }

    /// The first seeded routine, for previewing screens that need one.
    static var sampleRoutine: Routine {
        var descriptor = FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.sortIndex)])
        descriptor.fetchLimit = 1
        let found = (try? container.mainContext.fetch(descriptor)) ?? []
        return found.first ?? Routine(name: "Meditate", durationSeconds: 600)
    }

    private static func seed(into context: ModelContext) {
        let morning = RoutineList(
            name: "Morning",
            symbolName: "sun.max.fill",
            colorIdentifier: RoutineColor.orange.rawValue,
            sortIndex: 0
        )
        let strength = RoutineList(
            name: "Strength",
            symbolName: "dumbbell.fill",
            colorIdentifier: RoutineColor.red.rawValue,
            sortIndex: 1
        )
        // One pinned, one not, so the root preview shows both a tile and a row.
        morning.isPinned = true
        context.insert(morning)
        context.insert(strength)

        let samples: [(String, String, String, RoutineColor, Int, Int, RoutineList?)] = [
            ("Meditate", "Ten quiet minutes before anything else.", "figure.mind.and.body", .indigo, 600, 1, morning),
            ("Drink Water", "Eight glasses through the day.", "drop.fill", .cyan, 0, 8, morning),
            ("Stretch", "Full body, unhurried.", "figure.cooldown", .mint, 300, 1, morning),
            ("Push-Ups", "Three sets.", "figure.strengthtraining.traditional", .red, 0, 3, strength),
            ("Pull-Ups", "Two sets to failure.", "figure.strengthtraining.functional", .orange, 0, 2, strength),
            ("Read", "A chapter, paper only.", "book.fill", .brown, 1_200, 1, nil),
        ]

        let week = WeekPlanner.week(containing: Date())
        let today = DayKey.today

        for (index, sample) in samples.enumerated() {
            let (name, details, symbol, color, duration, target, list) = sample
            let routine = Routine(
                name: name,
                details: details,
                symbolName: symbol,
                colorIdentifier: color.rawValue,
                durationSeconds: duration,
                repetitionsPerDay: target,
                sortIndex: index,
                list: list
            )
            context.insert(routine)

            // A staggered history so the squares and the heatmap show a mix of
            // full, partial and empty days rather than a uniform block.
            for (offset, day) in week.enumerated() {
                let key = DayKey(day)
                guard key <= today else { break }
                guard (offset + index) % 3 != 0 else { continue }

                let count = max(1, target - (offset + index) % max(1, target))
                let completion = RoutineCompletion(day: key, count: count)
                context.insert(completion)
                completion.routine = routine
            }
        }
    }
}
#endif
