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

    let container: ModelContainer = {
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
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
