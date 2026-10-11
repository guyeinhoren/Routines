//
//  WelcomeView.swift
//  Routines
//

import SwiftUI

/// The sheet shown on first launch, in the shape of Apple's own welcome
/// screens: the app's icon at the top, a title, three points each with a
/// symbol, and one button to carry on.
///
/// It can be brought back from Settings, so it's written to make sense to
/// someone who already uses the app, not only to a newcomer.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    header

                    VStack(alignment: .leading, spacing: 26) {
                        WelcomePoint(
                            systemImage: "repeat.circle.fill",
                            tint: .orange,
                            title: Text("Keep Up What Matters", comment: "Welcome screen point about the app's purpose"),
                            detail: Text(
                                "Routines helps you track your routines, keep a streak going in the things that matter to you, and build new habits.",
                                comment: "Welcome screen explanation of the app's purpose"
                            )
                        )

                        WelcomePoint(
                            systemImage: "chart.bar.xaxis",
                            tint: .purple,
                            title: Text("Read Your Week at a Glance", comment: "Welcome screen point about the activity grid"),
                            detail: Text(
                                "Each square is a day, and it fills as you record a routine. The chart button shows a month of squares in each routine's colour — the deeper the colour, the more you did. Tap a week to see its routines.",
                                comment: "Welcome screen explanation of how to read the squares"
                            )
                        )

                        WelcomePoint(
                            systemImage: "play.circle.fill",
                            tint: .blue,
                            title: Text("Time Your Workouts", comment: "Welcome screen point about the play button"),
                            detail: Text(
                                "Press play in a list to time a workout. When it ends it can go into your calendar, so you can follow your workouts over time as part of your day.",
                                comment: "Welcome screen explanation of the play button"
                            )
                        )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
                .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button(action: onContinue) {
                Text("Continue", comment: "Closes the welcome screen")
                    .font(.headline)
                    .frame(maxWidth: 360)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }

    private var header: some View {
        VStack(spacing: 20) {
            Image("WelcomeIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .accessibilityHidden(true)

            Text("Welcome to “Routines”", comment: "Title of the welcome screen")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One point on the welcome screen: a symbol beside a title and a sentence.
private struct WelcomePoint: View {
    let systemImage: String
    let tint: Color
    let title: Text
    let detail: Text

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.headline)
                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Hebrew") {
    WelcomeView(onContinue: {})
        .environment(\.locale, Locale(identifier: "he_IL"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("English") {
    WelcomeView(onContinue: {})
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.layoutDirection, .leftToRight)
}
#endif
