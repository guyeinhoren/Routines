//
//  RoutineSymbolCatalog.swift
//  Routines
//

import Foundation

/// The symbols offered when choosing a routine's icon.
///
/// A curated list rather than every SF Symbol: the point is a quick pick from
/// shapes that read clearly at badge size, grouped so related habits sit
/// together in the picker.
enum RoutineSymbolCatalog {
    static let all: [String] = [
        // General
        "checkmark.circle.fill", "star.fill", "heart.fill", "flame.fill",
        "bolt.fill", "sparkles", "target", "flag.fill",

        // Movement
        "figure.run", "figure.walk", "figure.yoga", "figure.cooldown",
        "figure.mind.and.body", "figure.strengthtraining.traditional",
        "figure.pool.swim", "dumbbell.fill", "bicycle", "sportscourt.fill",

        // Mind and learning
        "book.fill", "book.closed.fill", "graduationcap.fill", "pencil",
        "lightbulb.fill", "brain.head.profile", "music.note", "paintbrush.fill",

        // Body and health
        "drop.fill", "leaf.fill", "carrot.fill", "fork.knife",
        "cup.and.saucer.fill", "pills.fill", "cross.case.fill", "bandage.fill",
        "waveform.path.ecg", "eye.fill", "ear.fill", "wind",

        // Rhythm of the day
        "sun.max.fill", "moon.fill", "bed.double.fill", "alarm.fill",
        "clock.fill", "calendar", "bell.fill", "hand.raised.fill",

        // Home and work
        "house.fill", "cart.fill", "creditcard.fill", "briefcase.fill",
        "laptopcomputer", "keyboard", "envelope.fill", "message.fill",

        // Out and about
        "phone.fill", "person.2.fill", "dog.fill", "cat.fill",
        "globe", "airplane", "car.fill", "camera.fill",

        // Milestones
        "trophy.fill", "medal.fill", "chart.line.uptrend.xyaxis", "calendar.badge.checkmark",
    ]
}
