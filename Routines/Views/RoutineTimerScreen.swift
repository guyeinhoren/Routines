//
//  RoutineTimerScreen.swift
//  Routines
//

import SwiftData
import SwiftUI

/// The full-screen countdown started from a timed routine's play button.
struct RoutineTimerScreen: View {
    let routine: Routine

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(DayTracker.self) private var dayTracker

    // No value at the declaration: the `@State` macro would treat that as the
    // authoritative one and ignore what `init` assigns.
    @State private var countdown: Countdown

    @AppStorage(SettingsKey.timerCountsAsCompletion) private var timerCountsAsCompletion = true

    /// Guards against recording twice if the finished state is observed again.
    @State private var hasRecordedRepetition = false

    @ScaledMetric(relativeTo: .largeTitle) private var remainingFontSize: CGFloat = 60

    init(routine: Routine) {
        self.routine = routine
        countdown = Countdown(seconds: routine.durationSeconds)
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 36) {
                header
                ring
                controls
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .overlay(alignment: .topLeading) {
            closeButton
        }
        .task {
            await countdown.run()
        }
        .onAppear {
            // The person already tapped play to get here.
            countdown.start()
        }
        .onChange(of: countdown.isFinished) { _, isFinished in
            guard isFinished else { return }
            recordRepetition()
        }
        .sensoryFeedback(.success, trigger: countdown.isFinished)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    private var background: some View {
        ZStack {
            Rectangle()
                .fill(.background)
            LinearGradient(
                colors: [routine.color.opacity(0.32), routine.color.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 12) {
            RoutineSymbolBadge(routine: routine, size: 52)

            Text(routine.name)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            if routine.hasDetails {
                // The rich version, so any formatting the person applied in the
                // editor carries through to the screen they actually stare at.
                Text(routine.richDetails)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(routine.color.opacity(0.18), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            Circle()
                .trim(from: 0, to: countdown.progress)
                .stroke(routine.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: countdown.progress)

            VStack(spacing: 6) {
                Text(remainingDescription)
                    .font(.system(size: remainingFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if countdown.isFinished {
                    Text("Complete", comment: "Shown in the timer when the countdown ends")
                        .font(.headline)
                        .foregroundStyle(routine.color)
                }
            }
            .padding(36)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 300)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Time remaining", comment: "VoiceOver label for the countdown"))
        .accessibilityValue(remainingDescription)
    }

    private var controls: some View {
        Group {
            if countdown.isFinished {
                Button {
                    dismiss()
                } label: {
                    Text("Done", comment: "Dismisses the finished timer")
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(routine.color)
            } else {
                Button {
                    countdown.toggle()
                } label: {
                    Image(systemName: countdown.isRunning ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 76, height: 76)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(
                    countdown.isRunning
                        ? Text("Pause", comment: "VoiceOver label for the pause button")
                        : Text("Resume", comment: "VoiceOver label for the resume button")
                )
            }
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .padding(20)
        .accessibilityLabel(Text("Close", comment: "VoiceOver label for the timer's close button"))
    }

    /// Rounds up so the display shows the configured length on the first frame
    /// and only reaches zero when the countdown is genuinely over.
    private var remainingDescription: String {
        let seconds = Int(countdown.remaining.rounded(.up))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600
            ? .hourMinuteSecond
            : .minuteSecond
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }

    private func recordRepetition() {
        guard timerCountsAsCompletion, !hasRecordedRepetition else { return }
        hasRecordedRepetition = true
        RoutineStore.recordRepetition(routine, on: dayTracker.today, in: context)
    }
}

#if DEBUG
#Preview {
    RoutineTimerScreen(routine: PreviewData.sampleRoutine)
        .environment(DayTracker())
        .modelContainer(PreviewData.container)
}
#endif
