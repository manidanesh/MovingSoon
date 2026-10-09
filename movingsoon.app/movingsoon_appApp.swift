//
//  movingsoon_appApp.swift
//  movingsoon.app
//
//  Created by Mani on 4/25/26.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct movingsoon_appApp: App {

    let container: ModelContainer?
    private let notificationDelegate: NotificationDelegate?

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
        self.notificationDelegate = container.map { NotificationDelegate(container: $0) }
        UNUserNotificationCenter.current().delegate = self.notificationDelegate
        // Permission itself is requested contextually by SmartReminderService once the
        // dashboard loads (see ZenDashboardView's .task) — asking here, before onboarding
        // even starts, gave users no reason to say yes and tanked opt-in.

        #if DEBUG
        // TEMPORARY — App Store screenshot seeding. Compiled out of Release builds by
        // #if DEBUG, and only runs when explicitly requested via env var, so it can't
        // affect real installs. Remove once screenshots are captured.
        if let container, ProcessInfo.processInfo.environment["SEED_SCREENSHOT_DATA"] == "1" {
            Self.seedScreenshotDataIfNeeded(container: container)
        } else if let container, ProcessInfo.processInfo.environment["SEED_SCREENSHOT_DATA"] == "interview" {
            Self.seedInterviewOnlyIfNeeded(container: container)
        }
        #endif
        if let container {
            LocationManager.shared.configure(context: container.mainContext)
        }
    }

    /// Preserve the only copy of the customer's progress if a store cannot open.
    /// Schema migration or a temporary file-access failure must never delete it.
    private static func makeContainer(schema: Schema, configuration: ModelConfiguration) -> ModelContainer? {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let logger = Logger(subsystem: "app.movingsoon", category: "Storage")
            let failure = error as NSError
            logger.error("Unable to open saved checklist: \(failure.domain, privacy: .public) code \(failure.code). Existing files retained.")
            return nil
        }
    }

    #if DEBUG
    /// TEMPORARY — populates a realistic move/profile/tasks so the dashboard has real
    /// content for App Store screenshots instead of an empty onboarding flow. Remove
    /// alongside the env-var check above once screenshots are captured.
    private static func seedScreenshotDataIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)
        guard let existing = try? context.fetch(FetchDescriptor<Move>()), existing.isEmpty else { return }

        let moveDate = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()
        let destinationZip = "80202"
        let (state, city) = ZipBucketService.bucket(zip: destinationZip)

        let move = Move(
            anchorDate: moveDate,
            originZip: "90210",
            destinationZip: destinationZip,
            destinationStateBucket: state,
            destinationCityBucket: city
        )
        context.insert(move)

        let profile = LifestyleProfile()
        profile.activeFlags = [
            .hasCar, .hasPartner, .hasChildren, .hasPets, .workFromHome,
            .usesAmazon, .usesNetflix, .usesSpotify, .hasGymMembership,
            .usesPlanetFitness, .hasStudentLoans, .hasInvestmentAccounts,
            .isRenting, .usesXfinity
        ]
        move.lifestyleProfile = profile
        context.insert(profile)

        let institutions = [
            FinancialInstitution(name: "Chase", initials: "CH", colorHex: "#117ACA", type: .bank,
                                  websiteURL: URL(string: "https://chase.com")),
            FinancialInstitution(name: "American Express", initials: "AE", colorHex: "#006FCF", type: .creditCard,
                                  websiteURL: URL(string: "https://americanexpress.com")),
            FinancialInstitution(name: "Fidelity", initials: "FI", colorHex: "#5D9B41", type: .investment,
                                  websiteURL: URL(string: "https://fidelity.com"))
        ]
        for institution in institutions {
            institution.move = move
            context.insert(institution)
        }
        move.institutions = institutions

        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: institutions)
        for (index, task) in tasks.enumerated() {
            if index > 0 && index % 3 == 0 { task.status = .completed } // leave the hero (index 0) toDo
            task.move = move
            context.insert(task)
        }
        move.tasks = tasks

        try? context.save()
    }

    /// TEMPORARY — a Move with no LifestyleProfile yet, so ContentView's phase router lands
    /// on the Lifestyle Interview screen for a screenshot instead of an empty onboarding flow.
    private static func seedInterviewOnlyIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)
        guard let existing = try? context.fetch(FetchDescriptor<Move>()), existing.isEmpty else { return }

        let moveDate = Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()
        let destinationZip = "80202"
        let (state, city) = ZipBucketService.bucket(zip: destinationZip)
        let move = Move(
            anchorDate: moveDate,
            originZip: "90210",
            destinationZip: destinationZip,
            destinationStateBucket: state,
            destinationCityBucket: city
        )
        context.insert(move)
        try? context.save()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView().modelContainer(container)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("Your saved checklist couldn’t open").font(.title2.weight(.semibold))
                    Text("Your data has been kept. Close and reopen the app to try again. If this continues, contact support before reinstalling.")
                        .foregroundStyle(.secondary)
                    Link("Contact support", destination: URL(string: "https://github.com/manidanesh/MovingSoon/issues")!)
                }
                .multilineTextAlignment(.center)
                .padding(28)
                .preferredColorScheme(.dark)
            }
        }
    }
}
