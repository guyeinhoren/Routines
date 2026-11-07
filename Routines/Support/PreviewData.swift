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
                for: Routine.self, RoutineList.self, RoutineCompletion.self, RoutineMeasurement.self, WorkoutSession.self,
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
        .modelContainer(container)
    }

    /// One list's routines, for previewing the routines screen directly.
    static var listScreen: some View {
        NavigationStack {
            RoutineListView(list: sampleList)
        }
        .environment(DayTracker())
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

    /// The seeded routine that carries a weight, for previewing the value chart.
    static var sampleValueRoutine: Routine {
        let found = (try? container.mainContext.fetch(FetchDescriptor<Routine>())) ?? []
        return found.first { $0.tracksValue } ?? sampleRoutine
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

        // A smart list gathering one tag across both lists above.
        let everyDay = RoutineList(
            name: "Every Day",
            symbolName: "number",
            colorIdentifier: RoutineColor.purple.rawValue,
            sortIndex: 2
        )
        everyDay.smartTag = "daily"
        context.insert(everyDay)

        let samples: [(String, String, String, RoutineColor, Int, Int, RoutineList?)] = [
            ("Meditate", "Ten quiet minutes before anything else.", "figure.mind.and.body", .indigo, 600, 1, morning),
            ("Drink Water", "Eight glasses through the day.", "drop.fill", .cyan, 0, 8, morning),
            ("Stretch", "Full body, unhurried.", "figure.cooldown", .mint, 300, 1, morning),
            ("Push-Ups", "Three sets.", "figure.strengthtraining.traditional", .red, 0, 3, strength),
            ("Pull-Ups", "Two sets to failure.", "figure.strengthtraining.functional", .orange, 0, 2, strength),
            ("Read", "A chapter, paper only.", "book.fill", .brown, 1_200, 1, nil),
        ]

        // Five weeks back, so the activity graph has earlier weeks worth
        // selecting rather than a single populated row.
        let today = DayKey.today
        let calendar = Calendar.current
        let thisWeekStart = WeekPlanner.week(containing: Date()).first ?? Date()
        let week: [Date] = (0..<35).compactMap {
            calendar.date(byAdding: .day, value: $0 - 28, to: thisWeekStart)
        }

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
            if ["Meditate", "Drink Water", "Push-Ups"].contains(name) {
                routine.tag = "daily"
            }
            context.insert(routine)

            // One routine with a weight, so the value and its chart have
            // something to show.
            if name == "Pull-Ups" {
                routine.tracksValue = true
                routine.valueUnit = "kg"
                let weights: [Double] = [10, 10, 12.5, 12.5, 15, 15, 17.5, 17.5, 20, 22.5, 22.5, 25]
                for (step, weight) in weights.enumerated() {
                    guard let day = calendar.date(byAdding: .day, value: -(weights.count - 1 - step) * 3, to: Date()) else { continue }
                    RoutineStore.setValue(weight, for: routine, on: DayKey(day), in: context)
                }
            }

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
