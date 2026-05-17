// ZenDashboardView.swift — Brutally Minimalist Action Hub
import SwiftUI
import SwiftData
import CoreLocation
import MessageUI

struct ZenDashboardView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @State private var showingMailComposer = false
    @State private var selectedAgenticTask: ChecklistTask?

    // Unsplash Integration
    @State private var unsplashService = UnsplashService()
    @State private var ambientImageURL: URL?

    // Smart Location Reminders
    @State private var locationManager = LocationManager()
    @State private var consentCardDismissed = false

    // MARK: - Consent card visibility predicate
    private var shouldShowConsentCard: Bool {
        // Never show again once consent has been granted (even after expiry)
        guard move.locationConsentGrantedAt == nil else { return false }
        // Session-dismissed
        guard !consentCardDismissed else { return false }
        // Only show when permission is not yet granted
        let status = locationManager.authorizationStatus
        return status == .notDetermined || status == .denied
    }

    // 1. Sort pending tasks by urgency (tMinusDays relative to anchorDate).
    // The lowest tMinusDays means it's due the earliest (e.g. -30 is due 30 days before move).
    private var pendingTasks: [ChecklistTask] {
        move.tasks
            .filter { $0.status == .toDo }
            .sorted { $0.tMinusDays < $1.tMinusDays }
    }

    private var heroTask: ChecklistTask? {
        // If USPS is uncompleted, always force it as Hero.
        if let usps = pendingTasks.first(where: { $0.isHeroItem }) {
            return usps
        }
        return pendingTasks.first
    }

    private var nextUpTasks: [ChecklistTask] {
        guard let hero = heroTask else { return [] }
        return Array(pendingTasks.filter { $0.id != hero.id }.prefix(2))
    }

    private var daysUntilMoveLabel: String {
        let days = move.daysUntilMove
        if days > 0  { return "T-Minus \(days) Days" }
        if days == 0 { return "Moving Day 🎉" }
        return "Day \(abs(days)) in your new home"
    }

    var body: some View {
        ZStack {
            // MARK: Ambient Background Layer
            if let url = ambientImageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .ignoresSafeArea()
                            .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                    } else {
                        // While loading, use a subtle skeleton or solid color
                        Theme.backgroundPrimary.ignoresSafeArea()
                    }
                }
            } else {
                // Local fallback while fetching or if network fails
                let backgroundAsset = CityBackgroundMapper.getBackgroundAsset(forZip: move.destinationZip, cityBucket: move.destinationCityBucket)
                Image(backgroundAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
            
            LinearGradient(
                colors: [Theme.backgroundPrimary.opacity(0.85), Theme.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if pendingTasks.isEmpty {
                // All done state
                VStack(spacing: 20) {
                    Text("All Caught Up.")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                    Text("Your move is fully orchestrated.")
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                VStack(spacing: 40) {
                    
                    // MARK: Momentum Ring & Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(daysUntilMoveLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.accentPrimary)
                                .textCase(.uppercase)
                                .tracking(1.5)

                            Text("Your Action Hub")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        
                        // Sleek Momentum Ring
                        ZStack {
                            Circle()
                                .stroke(Theme.backgroundElevated, lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: move.completionFraction)
                                .stroke(Theme.accentPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(), value: move.completionFraction)
                            
                            Text("\(Int(move.completionFraction * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(width: 50, height: 50)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // MARK: Location Consent Card
                    if shouldShowConsentCard {
                        LocationConsentCard(
                            onAllow: {
                                locationManager.move = move
                                locationManager.requestPermissions()
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    consentCardDismissed = true
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // MARK: Contextual Prompt Card
                    if let contextualTask = locationManager.activeContextualTask {
                        ContextualPromptCard(
                            task: contextualTask,
                            onYes: {
                                completeTask(contextualTask)
                                locationManager.activeContextualTask = nil
                            },
                            onRemindTomorrow: {
                                snoozeContextualTask(contextualTask)
                            },
                            onDontRemindAgain: {
                                muteContextualTask(contextualTask)
                            }
                        )
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                    }

                    Spacer()

                    // MARK: Hero Task
                    if let hero = heroTask {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Objective")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)
                                .padding(.horizontal, 24)

                            ZenHeroCard(
                                task: hero,
                                onComplete: { completeTask(hero) },
                                onAgenticAction: { triggerAgenticAction(for: hero) },
                                onSkip: { skipTask(hero) }
                            )
                                .padding(.horizontal, 20)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                        }
                    }

                    Spacer()

                    // MARK: Next Up Drawer
                    if !nextUpTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Next Up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)

                            VStack(spacing: 0) {
                                ForEach(nextUpTasks) { task in
                                    ZenDrawerRow(task: task)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 16)
                                    
                                    if task.id != nextUpTasks.last?.id {
                                        Rectangle()
                                            .fill(Theme.backgroundElevated)
                                            .frame(height: 0.5)
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                            .background(Theme.backgroundCard.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 40)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pendingTasks)
            }
        }
        .sheet(isPresented: $showingMailComposer) {
            if let task = selectedAgenticTask {
                MailComposeView(
                    toRecipients: [],
                    subject: "Address Change Request: \(task.title)",
                    messageBody: "Hello,\n\nPlease update my address on file to my new location.\n\nThank you.",
                    isShowing: $showingMailComposer
                )
            }
        }
        .task {
            // Fetch live background from Unsplash on load
            if ambientImageURL == nil {
                ambientImageURL = await unsplashService.fetchAmbientBackgroundURL(for: move.destinationZip, cityBucket: move.destinationCityBucket)
            }
            // Wire the move into LocationManager and check consent expiry
            locationManager.move = move
            locationManager.checkConsentExpiry()
            // If consent is already active, sync geofences
            locationManager.syncGeofencesIfActive()
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            // Persist locationConsentGrantedAt when authorization is granted
            if newStatus == .authorizedAlways || newStatus == .authorizedWhenInUse {
                try? modelContext.save()
            }
        }
    }

    private func completeTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            task.advanceStatus()
            try? modelContext.save()
            // Remove geofence for this task if it has one
            locationManager.taskStatusDidChange(task)
        }
    }

    private func skipTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation {
            // Push the task 7 days further out so it drops in urgency
            task.tMinusDays += 7
            try? modelContext.save()
        }
    }

    private func triggerAgenticAction(for task: ChecklistTask) {
        // Only open mail composer if the device can send mail
        guard MFMailComposeViewController.canSendMail() else {
            // Fallback: open the task's deep link directly if available
            if let url = task.deepLinkURL {
                UIApplication.shared.open(url)
            }
            return
        }
        selectedAgenticTask = task
        showingMailComposer = true
    }

    private func snoozeContextualTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            task.snoozedUntil = Date().addingTimeInterval(86400)
            try? modelContext.save()
            locationManager.activeContextualTask = nil
        }
    }

    private func muteContextualTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            task.isMuted = true
            try? modelContext.save()
            locationManager.activeContextualTask = nil
            locationManager.taskStatusDidChange(task)
        }
    }
}

// MARK: - Zen Hero Card
struct ZenHeroCard: View {
    let task: ChecklistTask
    let onComplete: () -> Void
    let onAgenticAction: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            // Subtle urgency gradient
            let gradientColor = task.priority == .critical ? Color.red.opacity(0.15) : Theme.accentPrimary.opacity(0.1)
            
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [gradientColor, Theme.backgroundCard], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    Text(task.title)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if task.actionType == .agenticUpdate {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.accentPrimary)
                            .font(.system(size: 20))
                    }
                }

                HStack {
                    Label(task.category.rawValue, systemImage: task.category.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.backgroundElevated)
                        .clipShape(Capsule())

                    if let poi = task.poiCategory {
                        Label(poi.rawValue, systemImage: "mappin.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.backgroundElevated)
                            .clipShape(Capsule())
                    }
                }

                VStack(spacing: 12) {
                    if task.actionType == .agenticUpdate {
                        Button(action: onAgenticAction) {
                            Label("Auto-Update", systemImage: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accentPrimary)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Theme.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                    } else {
                        Button(action: onComplete) {
                            Label("Mark Completed", systemImage: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.backgroundElevated)
                                .foregroundColor(Theme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    
                    // Secondary Skip Button
                    Button(action: onSkip) {
                        Text("Skip for Now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Contextual Prompt Card
struct ContextualPromptCard: View {
    let task: ChecklistTask
    let onYes: () -> Void
    let onRemindTomorrow: () -> Void
    let onDontRemindAgain: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accentPrimary.opacity(0.15), Theme.backgroundCard], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.accentPrimary.opacity(0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Label("Location Match", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accentPrimary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    Spacer()
                }

                let displayName = task.institutionName ?? task.title
                Text("We noticed you're near \(displayName). Have you updated your address on file?")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)

                VStack(spacing: 12) {
                    Button(action: onYes) {
                        Label("Yes, Mark Completed", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accentPrimary)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button(action: onRemindTomorrow) {
                        Label("No, Remind Me Tomorrow", systemImage: "clock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.backgroundElevated)
                            .foregroundColor(Theme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button(action: onDontRemindAgain) {
                        Text("Don't remind me again")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Zen Drawer Row
struct ZenDrawerRow: View {
    let task: ChecklistTask

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textSecondary) // Dimmer than Hero
                
                Text(task.category.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
            Spacer()
            if task.actionType == .agenticUpdate {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.accentPrimary.opacity(0.5))
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(Theme.textSecondary.opacity(0.2))
            }
        }
    }
}
