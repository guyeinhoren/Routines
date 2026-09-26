//
//  WorkoutBanner.swift
//  Routines
//

import SwiftData
import SwiftUI

/// Shown at the top of a list while a workout is underway: which list it
/// covers, how long it has been running, and how to end it.
///
/// The list itself is the workout's scope, so there is nothing here to filter —
/// unlike the tag-based version this replaced.
struct WorkoutBanner: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var workout

    private var tint: Color {
        RoutineColor(identifier: session.listColorIdentifier).color
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint)

                Image(systemName: session.listSymbolName)
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.listName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(session.startDate, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Elapsed time", comment: "VoiceOver label for the workout timer"))
            }

            Spacer(minLength: 8)

            Button {
                Task { await workout.end(in: context) }
            } label: {
                Text("End", comment: "Short button that finishes the current workout")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
