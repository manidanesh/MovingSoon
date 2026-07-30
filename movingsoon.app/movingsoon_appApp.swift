//
//  movingsoon_appApp.swift
//  movingsoon.app
//
//  Created by Mani on 4/25/26.
//

import SwiftUI
import SwiftData

@main
struct movingsoon_appApp: App {

    let container: ModelContainer
    private let notificationDelegate: NotificationDelegate

    init() {
        let schema = Schema([
            Move.self,
            ChecklistTask.self,
            VerificationEvent.self,
            PendingSignal.self,
            FinancialInstitution.self,
            LifestyleProfile.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = Self.makeContainer(schema: schema, configuration: config)
        self.container = container
        self.notificationDelegate = NotificationDelegate(container: container)
        UNUserNotificationCenter.current().delegate = self.notificationDelegate
        // Permission itself is requested contextually by SmartReminderService once the
        // dashboard loads (see ZenDashboardView's .task) — asking here, before onboarding
        // even starts, gave users no reason to say yes and tanked opt-in.
    }

    /// Falls back to a fresh on-disk store if the existing one fails to open (e.g. corrupted
    /// after an interrupted write, or an un-migratable schema change in a future update)
    /// instead of fatalError-ing every launch with no recovery path. This app has no server
    /// sync, so losing a local store means redoing onboarding — undesirable, but survivable,
    /// unlike a permanent crash loop.
    private static func makeContainer(schema: Schema, configuration: ModelConfiguration) -> ModelContainer {
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        destroyStore(at: configuration.url)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer even after resetting the store: \(error)")
        }
    }

    private static func destroyStore(at url: URL) {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        guard let siblings = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            try? fileManager.removeItem(at: url)
            return
        }
        // Also removes the SQLite -wal/-shm sidecar files, not just the main store file.
        for file in siblings where file.lastPathComponent.hasPrefix(baseName) {
            try? fileManager.removeItem(at: file)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
