//
//  CloudSyncDiagnostics.swift
//  Routines
//

#if DEBUG
import CoreData
import Foundation
import OSLog

/// Logs every iCloud sync event in debug builds.
///
/// SwiftData mirrors to CloudKit through Core Data, which reports each setup,
/// import and export as a notification. Logging them is the only way to see,
/// from a development build, that the data really is reaching iCloud — and so
/// that it would survive the app being deleted.
enum CloudSyncDiagnostics {
    private static let logger = Logger(subsystem: "GuyEinhoren.Routines", category: "CloudSync")
    nonisolated(unsafe) private static var observer: NSObjectProtocol?

    static func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            else { return }

            let kind = switch event.type {
            case .setup: "setup"
            case .import: "import"
            case .export: "export"
            @unknown default: "other"
            }
            let state = event.endDate == nil ? "started" : (event.succeeded ? "succeeded" : "failed")

            if let error = event.error {
                logger.error("CloudSync \(kind, privacy: .public) \(state, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("CloudSync \(kind, privacy: .public) \(state, privacy: .public)")
            }
        }
    }
}
#endif
