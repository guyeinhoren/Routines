//
//  RoutinesWidgetBundle.swift
//  RoutinesWidget
//

import SwiftUI
import WidgetKit

/// The extension's widgets: the timer's Live Activity, the one the app starts. There are
/// no Home Screen widgets yet.
@main
struct RoutinesWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoutineTimerLiveActivity()
        RoutineStatusLiveActivity()
    }
}
