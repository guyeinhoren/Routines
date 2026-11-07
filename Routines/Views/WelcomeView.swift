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
                                "Each square is a day, and it fills as you record a routine. The chart button shows a month of squares in the list's colour — the deeper the colour, the more routines you completed. Tap a week to see its routines.",
                                comment: "Welcome screen explanation of how to read the squares"
                            )
                        )

                        WelcomePoint(
                            systemImage: "timer.circle.fill",
                            tint: .blue,
                            title: Text("Time a Routine", comment: "Welcome screen point about routine timers"),
                            detail: Text(
                                "Give a routine a duration, then start its timer from the routine's details. When the timer ends, it counts as one repetition for today.",
                                comment: "Welcome screen explanation of routine timers"
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
            AppIconImage()
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)

            Text("Welcome to “Routines”", comment: "Title of the welcome screen")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The app's own icon, read from what's installed rather than kept as a copy,
/// so it always matches the icon on the Home Screen or in the Dock.
private struct AppIconImage: View {
    var body: some View {
        #if os(macOS)
        // Already drawn in the Mac's icon shape, with its shadow.
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #else
        if let icon = Self.installedIcon {
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        } else {
            Image(systemName: "sunrise.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(18)
                .foregroundStyle(.blue)
        }
        #endif
    }

    #if !os(macOS)
    /// The largest of the icon images Xcode writes into the bundle, found by
    /// the names Info.plist lists for them.
    private static var installedIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last
        else { return nil }
        return UIImage(named: name)
    }
    #endif
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
