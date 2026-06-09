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
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            self.notificationDelegate = NotificationDelegate(container: container)
            UNUserNotificationCenter.current().delegate = self.notificationDelegate
            // Request notification permission at launch so location notifications can fire
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
