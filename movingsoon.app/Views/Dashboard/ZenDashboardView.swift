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

    // Navigation
    @State private var showingAllTasks = false
    @State private var showingEditMove = false

    // Reminders
    @State private var reminderService = SmartReminderService()

    // MARK: - Consent card visibility predicate
    private var shouldShowConsentCard: Bool {
        // Never show again once consent has been granted (even after expiry)
        guard move.locationConsentGrantedAt == nil else { return false }
        guard move.daysUntilMove <= 30 else { return false }
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
                ScrollView(showsIndicators: false) {
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

                    // MARK: View All Tasks
                    Button {
                        showingAllTasks = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("View All \(move.totalCount) Tasks")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.backgroundCard.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    // MARK: Achievement Milestones & Master Checklist
                    AchievementMilestoneSection(move: move)
                    } // end VStack
                    .padding(.top, 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pendingTasks)
                } // end ScrollView
            } // end else
        } // end ZStack
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
        .sheet(isPresented: $showingAllTasks) {
            NavigationStack {
                DashboardView(move: move)
                    .navigationTitle("All Tasks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingAllTasks = false }
                                .foregroundColor(Theme.accentPrimary)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingEditMove) {
            EditMoveView(move: move)
                .preferredColorScheme(.dark)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditMove = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Theme.textSecondary)
                }
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
            // Schedule hero task daily reminder
            reminderService.scheduleHeroTaskReminder(heroTask: heroTask)
            // Schedule T-minus reminders for tasks due in 3 days
            reminderService.scheduleTMinusReminders(tasks: move.tasks, moveDate: move.anchorDate)
        }
        .onChange(of: heroTask?.id) { _, _ in
            reminderService.scheduleHeroTaskReminder(heroTask: heroTask)
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
            // Advance twice to jump toDo → pendingVerification → completed in one tap
            task.advanceStatus()
            if task.status == .pendingVerification {
                task.advanceStatus()
            }
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

    /// Human-readable due date label derived from tMinusDays relative to move anchor.
    private var dueDateLabel: String? {
        guard let move = task.move else { return nil }
        let dueDate = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? move.anchorDate
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysLeft > 1  { return "Due in \(daysLeft) days" }
        if daysLeft == 1 { return "Due tomorrow" }
        if daysLeft == 0 { return "Due today" }
        return "Overdue"
    }

    private var isOverdue: Bool {
        guard let move = task.move else { return false }
        let dueDate = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? move.anchorDate
        return dueDate < Date()
    }

    var body: some View {
        ZStack {
            let gradientColor = task.priority == .critical ? Color.red.opacity(0.15) : Theme.accentPrimary.opacity(0.08)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [gradientColor, Theme.backgroundCard],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 20) {

                // MARK: Question + due date
                VStack(alignment: .leading, spacing: 8) {
                    // Category + due date row
                    HStack(spacing: 8) {
                        Label(task.category.rawValue, systemImage: task.category.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.backgroundElevated)
                            .clipShape(Capsule())

                        Spacer()

                        if let label = dueDateLabel {
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isOverdue ? Theme.accentPrimary : Theme.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background((isOverdue ? Theme.accentPrimary : Color.white).opacity(0.08))
                                .clipShape(Capsule())
                        }

                        if task.actionType == .agenticUpdate {
                            Image(systemName: "sparkles")
                                .foregroundColor(Theme.accentPrimary)
                                .font(.system(size: 18))
                        }
                    }

                    // The question
                    Text("Have you updated your address with **\(task.title)**?")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: Actions
                VStack(spacing: 10) {
                    if task.actionType == .agenticUpdate {
                        Button(action: onAgenticAction) {
                            Label("Auto-Update Address", systemImage: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.accentPrimary)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Theme.accentPrimary.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onComplete) {
                            Text("Mark as Done")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.accentPrimary)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Theme.accentPrimary.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onSkip) {
                        Text("I'll set this up later")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
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

                HStack(spacing: 10) {
                    Button(action: onRemindTomorrow) {
                        Text("Remind me tomorrow")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: onYes) {
                        Text("Yes, I updated it")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accentPrimary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
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

// MARK: - Achievement Milestones & Master Checklist

enum AchievementClusterType: String, CaseIterable {
    case utilities = "🔌 Utility & Housing Grid"
    case media = "🍿 Media & Digital Subscriptions"
    case financial = "💳 Financial & Payment Systems"
    case government = "🏛️ Government & Essential Identity"
    case lifestyle = "🌿 Lifestyle & Healthcare"

    var title: String { rawValue }

    var description: String {
        switch self {
        case .utilities: return "Power, water, internet, HOA, security, and home protection."
        case .media: return "Streaming, cable, gaming, app stores, and digital media."
        case .financial: return "Banks, loans, investments, PayPal, Apple Pay, and digital wallets."
        case .government: return "USPS, DMV, voter registration, IRS, SSA, and professional licenses."
        case .lifestyle: return "Doctors, pharmacies, vets, auto/life insurance, and memberships."
        }
    }

    var accentColor: Color {
        switch self {
        case .utilities: return Color.orange
        case .media: return Color.purple
        case .financial: return Color.green
        case .government: return Color.blue
        case .lifestyle: return Color.pink
        }
    }

    var celebratoryMessage: String {
        switch self {
        case .utilities: return "Milestone Unlocked: Utility & Housing Grid Fully Secured! ⚡"
        case .media: return "Milestone Unlocked: Media & Digital Subscriptions Mastered! 🍿"
        case .financial: return "Milestone Unlocked: Financial & Payment Systems Safeguarded! 🔒"
        case .government: return "Milestone Unlocked: Government & Essential Identity Established! 🏛️"
        case .lifestyle: return "Milestone Unlocked: Lifestyle & Healthcare Orchestration Complete! 🌿"
        }
    }

    func filterTasks(_ tasks: [ChecklistTask]) -> [ChecklistTask] {
        switch self {
        case .utilities:
            return tasks.filter { task in
                task.category == .utilities ||
                (task.category == .other && (task.title.contains("HOA") || task.title.contains("Parking") || task.title.contains("Neighbor"))) ||
                (task.category == .insurance && (task.title.contains("Warranty") || task.title.contains("Solar")))
            }
        case .media:
            return tasks.filter { task in
                task.category == .subscriptions &&
                task.category != .utilities
            }.filter { task in
                // Exclude shopping/food/fitness items from media cluster
                let shoppingKeywords = ["Amazon", "Costco", "Walmart", "Target", "Sam's", "BJ's", "Chewy",
                                        "Fitness", "Gym", "AARP", "Publix", "H-E-B", "Meijer", "Wegmans",
                                        "Kroger", "Safeway", "Albertsons", "Barnes", "Best Buy", "IKEA",
                                        "Wayfair", "DoorDash", "Uber Eats", "Grubhub", "Instacart",
                                        "HelloFresh", "Blue Apron", "Meal Kit", "Planet Fitness",
                                        "Equinox", "LA Fitness", "Peloton", "ClassPass", "CrossFit",
                                        "Orangetheory", "YMCA", "24 Hour", "Life Time", "JCC", "VASA",
                                        "EoS", "Chuze", "Crunch", "Anytime Fitness"]
                return !shoppingKeywords.contains(where: { task.title.contains($0) })
            }
        case .financial:
            return tasks.filter { task in
                task.category == .financial
            }
        case .government:
            return tasks.filter { task in
                task.category == .postal ||
                task.category == .government ||
                task.category == .legal ||
                task.category == .employer ||
                task.category == .education
            }
        case .lifestyle:
            let claimedIds: Set<UUID> = Set(
                AchievementClusterType.utilities.filterTasks(tasks).map { $0.id } +
                AchievementClusterType.media.filterTasks(tasks).map { $0.id } +
                AchievementClusterType.financial.filterTasks(tasks).map { $0.id } +
                AchievementClusterType.government.filterTasks(tasks).map { $0.id }
            )
            return tasks.filter { !claimedIds.contains($0.id) }
        }
    }
}

struct AchievementMilestoneSection: View {
    let move: Move
    @State private var expandedClusters: Set<AchievementClusterType> = []
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Achievement Milestones")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(2)
                .padding(.horizontal, 24)

            VStack(spacing: 16) {
                ForEach(AchievementClusterType.allCases, id: \.self) { cluster in
                    let clusterTasks = cluster.filterTasks(move.tasks)
                    if !clusterTasks.isEmpty {
                        let completedTasks = clusterTasks.filter { $0.status == .completed }
                        let pendingTasks = clusterTasks.filter { $0.status != .completed }
                        let isFullyAchieved = pendingTasks.isEmpty
                        let isExpanded = expandedClusters.contains(cluster)

                        VStack(spacing: 0) {
                            // Cluster Header Card
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if isExpanded { expandedClusters.remove(cluster) }
                                    else { expandedClusters.insert(cluster) }
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(isFullyAchieved ? Theme.accentSuccess.opacity(0.2) : cluster.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: isFullyAchieved ? "trophy.fill" : "target")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(isFullyAchieved ? Theme.accentSuccess : cluster.accentColor)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cluster.title)
                                            .font(.system(size: 16, weight: .bold, design: .serif))
                                            .foregroundColor(Theme.textPrimary)

                                        Text(isFullyAchieved ? cluster.celebratoryMessage : cluster.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(isFullyAchieved ? Theme.accentSuccess : Theme.textSecondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    // Progress Pill
                                    HStack(spacing: 4) {
                                        Text("\(completedTasks.count)/\(clusterTasks.count)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isFullyAchieved ? Theme.accentSuccess.opacity(0.2) : Theme.backgroundElevated)
                                    .foregroundColor(isFullyAchieved ? Theme.accentSuccess : Theme.textSecondary)
                                    .clipShape(Capsule())
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(isFullyAchieved ? LinearGradient(colors: [Theme.accentSuccess.opacity(0.15), Theme.backgroundCard], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [cluster.accentColor.opacity(0.1), Theme.backgroundCard], startPoint: .topLeading, endPoint: .bottomTrailing))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(isFullyAchieved ? Theme.accentSuccess.opacity(0.4) : cluster.accentColor.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            // Expanded Tasks List
                            if isExpanded {
                                VStack(spacing: 12) {
                                    // Pending Section
                                    if !pendingTasks.isEmpty {
                                        Text("Pending Updates (\(pendingTasks.count))")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(cluster.accentColor)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 8)

                                        ForEach(pendingTasks) { task in
                                            ZenMilestoneTaskRow(task: task, onComplete: { completeTask(task) })
                                        }
                                    }

                                    // Completed Section
                                    if !completedTasks.isEmpty {
                                        Text("Completed Achievements (\(completedTasks.count))")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Theme.accentSuccess)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 8)

                                        ForEach(completedTasks) { task in
                                            ZenMilestoneTaskRow(task: task, onComplete: { completeTask(task) })
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 16)
                                .background(Theme.backgroundCard.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 40)
    }

    private func completeTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation {
            if task.status == .completed {
                task.resetStatus()
            } else {
                task.advanceStatus()
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Zen Milestone Task Row
struct ZenMilestoneTaskRow: View {
    let task: ChecklistTask
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onComplete) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(task.status == .completed ? Theme.accentSuccess : Theme.textSecondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(task.status == .completed ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(task.status == .completed, color: Theme.textSecondary)

                HStack {
                    Text(task.category.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))

                    if let poi = task.poiCategory {
                        Text("• \(poi.rawValue)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                    }
                }
            }

            Spacer()

            if task.status != .completed {
                if task.actionType == .agenticUpdate {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accentPrimary)
                } else if let url = task.deepLinkURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.accentPrimary.opacity(0.8))
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.backgroundElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
