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

    // Snoozed task IDs (persisted via snoozedUntil on the task itself)
    @State private var sessionSkippedTaskIDs: Set<UUID> = []

    // Undo support
    @State private var lastCompletedTask: ChecklistTask? = nil
    @State private var undoVisible: Bool = false
    @State private var undoTimer: Timer? = nil

    // Pinned hero override — user promoted a Next Up task to hero
    @State private var pinnedHeroID: UUID? = nil

    // Celebration (unused but kept for overlay compatibility)
    @State private var celebrationTask: ChecklistTask? = nil

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
        let now = Date()
        return move.tasks
            .filter {
                $0.status == .toDo &&
                !sessionSkippedTaskIDs.contains($0.id) &&
                ($0.snoozedUntil == nil || $0.snoozedUntil! < now)
            }
            .sorted { $0.tMinusDays < $1.tMinusDays }
    }

    private var heroTask: ChecklistTask? {
        // If user pinned a specific task to hero, show it (if still pending)
        if let pinned = pinnedHeroID,
           let task = pendingTasks.first(where: { $0.id == pinned }) {
            return task
        }
        // USPS (isHeroItem) gets priority
        if let usps = pendingTasks.first(where: { $0.isHeroItem }) { return usps }
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

    /// Count tasks that are genuinely overdue (fix #11: post-move tasks not overdue until move date passes)
    private var overdueCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let moveDay = Calendar.current.startOfDay(for: move.anchorDate)
        return move.tasks.filter { task in
            guard task.status == .toDo else { return false }
            // Positive tMinusDays = task meant for after the move — only overdue once move has passed
            if task.tMinusDays > 0 && today <= moveDay { return false }
            let due = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? move.anchorDate
            return Calendar.current.startOfDay(for: due) < today
        }.count
    }

    /// Count tasks due within the next 7 days
    private var dueThisWeekCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return 0 }
        return move.tasks.filter { task in
            guard task.status == .toDo else { return false }
            let due = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? move.anchorDate
            let dueDay = Calendar.current.startOfDay(for: due)
            return dueDay >= today && dueDay <= weekEnd
        }.count
    }

    /// Status summary line shown below completion %
    private var progressContextLabel: String? {
        if overdueCount > 0 && dueThisWeekCount > 0 {
            return "\(overdueCount) overdue · \(dueThisWeekCount) due this week"
        } else if overdueCount > 0 {
            return "\(overdueCount) overdue"
        } else if dueThisWeekCount > 0 {
            return "\(dueThisWeekCount) due this week"
        }
        return nil
    }

    /// Primary title — neighbourhood or city name only (no full "Lowry, Denver, CO" in one bold line)
    private var dashboardTitle: String {
        if let hood = move.destinationNeighborhood {
            // e.g. "Lowry, Denver, CO" → just "Lowry"
            let first = hood.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? hood
            return "Moving to \(first)"
        }
        let city = move.destinationCityBucket?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        if let city = city { return "Moving to \(city)" }
        return "Moving to \(move.destinationStateBucket)"
    }

    /// Subtitle line — rest of the location (e.g. "Denver, CO") when neighbourhood is set
    private var dashboardSubtitle: String? {
        guard let hood = move.destinationNeighborhood else { return nil }
        let parts = hood.components(separatedBy: ",").dropFirst()
        let rest = parts.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ", ")
        return rest.isEmpty ? nil : rest
    }

    /// Short "From → To" route string shown beneath the main title.
    private var routeLabel: String? {
        let from = move.originNeighborhood ?? (move.originZip.flatMap { $0.isEmpty ? nil : $0 })
        let to   = move.destinationNeighborhood ?? move.destinationZip
        guard let from = from, !from.isEmpty else { return nil }
        return "\(from)  →  \(to)"
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {

                    // MARK: Momentum Ring & Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(daysUntilMoveLabel)
                                .themeText(13, weight: .medium)
                                .foregroundColor(Theme.accentPrimary)
                                .textCase(.uppercase)
                                .tracking(1.5)

                            Text(dashboardTitle)
                                .themeSerif(28, weight: .bold)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            // City/state subtitle when neighbourhood is set (#12)
                            if let subtitle = dashboardSubtitle {
                                Text(subtitle)
                                    .themeText(13, weight: .regular)
                                    .foregroundColor(Theme.textSecondary)
                            }

                            // From → To route pill (only when origin is known)
                            if let route = routeLabel {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right")
                                        .themeText(9, weight: .bold)
                                        .foregroundColor(Theme.textTertiary)
                                    Text(route)
                                        .themeText(11, weight: .medium)
                                        .foregroundColor(Theme.textTertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.backgroundElevated.opacity(0.8))
                                .clipShape(Capsule())
                            }

                            // Progress context (#5)
                            if let context = progressContextLabel {
                                Text(context)
                                    .themeText(12, weight: .medium)
                                    .foregroundColor(overdueCount > 0 ? Theme.priorityCritical : Theme.textSecondary)
                            } else {
                                Text("\(Int(move.completionFraction * 100))% complete")
                                    .themeText(13, weight: .regular)
                                    .foregroundColor(Theme.textSecondary)
                            }
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
                                .themeRounded(12, weight: .bold)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(width: 50, height: 50)

                        // Settings button
                        Button { showingEditMove = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .themeText(16, weight: .medium)
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(Theme.backgroundElevated, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Move settings")
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
                            },
                            locationStatus: locationManager.authorizationStatus
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
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }

                    // MARK: Hero Task
                    if pendingTasks.isEmpty {
                        VStack(spacing: 20) {
                            Text("All Caught Up.")
                                .themeSerif(32, weight: .bold)
                                .foregroundColor(Theme.textPrimary)
                            Text("Your move is fully orchestrated.")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if let hero = heroTask {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Do This Now")
                                .themeText(12, weight: .semibold)
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
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                        }
                    }

                    // MARK: Next Up Drawer
                    if !nextUpTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Next Up")
                                .themeText(12, weight: .semibold)
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)

                            VStack(spacing: 0) {
                                ForEach(nextUpTasks) { task in
                                    // #10 — tapping promotes to hero
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                            pinnedHeroID = task.id
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        ZenDrawerRow(task: task)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 16)
                                    }
                                    .buttonStyle(.plain)
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

                            // #3 — See all tasks link
                            Button { showingAllTasks = true } label: {
                                HStack(spacing: 4) {
                                    Text("See all \(move.tasks.filter { $0.status != .completed }.count) tasks")
                                        .themeText(13, weight: .medium)
                                        .foregroundColor(Theme.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .themeText(11, weight: .semibold)
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        }
                        .padding(.bottom, 24)
                    } else if !pendingTasks.isEmpty {
                        // No "Next Up" tasks but still have pending — still show the link
                        Button { showingAllTasks = true } label: {
                            HStack(spacing: 4) {
                                Text("See all \(move.tasks.filter { $0.status != .completed }.count) tasks")
                                    .themeText(13, weight: .medium)
                                    .foregroundColor(Theme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .themeText(11, weight: .semibold)
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    // MARK: Today's Priorities — urgent tasks, not a flat list of 68
                    TodaysPrioritiesSection(
                        move: move,
                        excludedTaskIDs: Set([heroTask?.id].compactMap { $0 }).union(nextUpTasks.map(\.id)),
                        onTaskComplete: { task in completeTask(task) },
                        onViewAll: { showingAllTasks = true }
                    )

                    // MARK: Move Timeline — when do things need to happen
                    MoveTimelineSection(move: move)

                } // end VStack
                .frame(width: geo.size.width) // ← pins content to exact screen width
                .padding(.bottom, 40)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pendingTasks)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background {
                // Background layer — completely outside layout flow
                ZStack {
                    let backgroundAsset = CityBackgroundMapper.getBackgroundAsset(
                        forZip: move.destinationZip,
                        cityBucket: move.destinationCityBucket
                    )
                    Image(backgroundAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    if let url = ambientImageURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                            }
                        }
                    }

                    LinearGradient(
                        colors: [Theme.backgroundPrimary.opacity(0.85), Theme.backgroundPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .dynamicTypeSize(...(.accessibility1))
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
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            // #2 — Undo toast
            VStack {
                Spacer()
                if undoVisible {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.accentSuccess)
                        Text("Marked as done")
                            .themeText(14, weight: .medium)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button("Undo") { undoLastCompletion() }
                            .themeText(14, weight: .bold)
                            .foregroundColor(Theme.accentPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentSuccess.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: undoVisible)
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
            // Ask for notification permission here, contextually — once the user has reached
            // their dashboard and reminders are actually about to be scheduled — rather than
            // at cold launch before onboarding, where there's no reason yet to say yes.
            reminderService.requestPermissions()
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
                modelContext.saveOrLog()
            }
        }
    }

    // #2 — complete with undo support
    private func completeTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation {
            task.advanceStatus()
            if task.status == .pendingVerification {
                task.advanceStatus()
            }
            modelContext.saveOrLog()
            locationManager.taskStatusDidChange(task)
        }

        // Show undo toast for 4 seconds
        lastCompletedTask = task
        withAnimation(.spring(response: 0.4)) { undoVisible = true }
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { undoVisible = false }
        }
    }

    private func undoLastCompletion() {
        guard let task = lastCompletedTask else { return }
        undoTimer?.invalidate()
        withAnimation(.spring(response: 0.4)) { undoVisible = false }
        withAnimation {
            task.resetStatus()
            modelContext.saveOrLog()
        }
        lastCompletedTask = nil
    }

    // #1 — real 3-day snooze, not a session-only hide
    private func skipTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            task.snoozedUntil = Date().addingTimeInterval(3 * 86400) // 3 days
            modelContext.saveOrLog()
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
            modelContext.saveOrLog()
            locationManager.activeContextualTask = nil
        }
    }

    private func muteContextualTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            task.isMuted = true
            modelContext.saveOrLog()
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

    /// Per-category question label (#9)
    private var heroQuestionLabel: String {
        if task.isHeroItem { return "First thing — set up your mail forwarding with" }
        if task.institutionName != nil {
            return "Have you updated your address with"
        }
        switch task.category {
        case .government:   return "Have you notified"
        case .utilities:    return "Have you updated your address with"
        case .healthcare:   return "Have you updated your records with"
        case .insurance:    return "Have you updated your policy address with"
        case .employer:     return "Have you updated your HR records at"
        case .subscriptions: return "Have you updated your billing address with"
        case .legal:        return "Have you filed your change of address with"
        case .education:    return "Have you updated your records with"
        default:            return "Have you updated your address with"
        }
    }

    var body: some View {
        ZStack {
            let gradientColor = task.priority == .critical ? Theme.priorityCritical.opacity(0.15) : Theme.accentPrimary.opacity(0.08)

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

                // MARK: Question + title
                VStack(alignment: .leading, spacing: 12) {
                    // Due date + agentic badge row
                    HStack(spacing: 8) {
                        if let label = dueDateLabel {
                            Text(label)
                                .themeText(11, weight: .semibold)
                                .foregroundColor(isOverdue ? Theme.priorityCritical : Theme.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((isOverdue ? Theme.priorityCritical : Color.white).opacity(0.08))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if task.actionType == .agenticUpdate {
                            Image(systemName: "sparkles")
                                .foregroundColor(Theme.accentPrimary)
                                .themeText(16)
                        }
                    }

                    // Small question label — per category (#9)
                    Text(heroQuestionLabel)
                        .themeText(13, weight: .regular)
                        .foregroundColor(Theme.textSecondary)

                    // Large emoji + task title
                    Text("\(task.category.emoji) \(task.title)")
                        .themeSerif(26, weight: .bold)
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: Actions
                VStack(spacing: 10) {
                    if task.actionType == .agenticUpdate {
                        Button(action: onAgenticAction) {
                            Label("Auto-Update Address", systemImage: "paperplane.fill")
                                .themeText(16, weight: .bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.accentPrimary)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Theme.accentPrimary.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    } else if let url = task.deepLinkURL {
                        // Primary: open the service directly
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right")
                                    .themeText(14, weight: .bold)
                                Text("Update Now")
                                    .themeText(16, weight: .bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.accentPrimary)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Theme.accentPrimary.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)

                        // Secondary: already done
                        Button(action: onComplete) {
                            Text("I already updated this ✓")
                                .themeText(15, weight: .semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.backgroundElevated)
                                .foregroundColor(Theme.accentSuccess)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // No deep link — just mark done
                        Button(action: onComplete) {
                            Text("Mark as Done")
                                .themeText(16, weight: .bold)
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
                        Text("Remind me in 3 days")
                            .themeText(15, weight: .semibold)
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        .themeText(13, weight: .bold)
                        .foregroundColor(Theme.accentPrimary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    Spacer()
                }

                let displayName = task.institutionName ?? task.title
                Text("We noticed you're near \(displayName). Have you updated your address on file?")
                    .themeSerif(18, weight: .semibold)
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    Button(action: onRemindTomorrow) {
                        Text("Remind me tomorrow")
                            .themeText(15, weight: .semibold)
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: onYes) {
                        Text("Yes, I updated it")
                            .themeText(15, weight: .bold)
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
        HStack(spacing: 10) {
            Circle()
                .fill(task.priority.color)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .themeText(16, weight: .medium)
                    .foregroundColor(Theme.textSecondary)
                Text(task.category.rawValue)
                    .themeText(12)
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
            Spacer()
            if task.actionType == .agenticUpdate {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.accentPrimary.opacity(0.5))
            } else if task.deepLinkURL != nil {
                Image(systemName: "arrow.up.right.circle")
                    .themeText(16)
                    .foregroundColor(Theme.textTertiary.opacity(0.4))
            }
        }
    }
}

// MARK: - Today's Priorities Section
struct TodaysPrioritiesSection: View {
    let move: Move
    /// Ids already shown as the Hero card or in the Next Up drawer — excluded here to avoid
    /// showing the same task three times on one screen.
    let excludedTaskIDs: Set<UUID>
    let onTaskComplete: (ChecklistTask) -> Void
    let onViewAll: () -> Void
    @Environment(\.modelContext) private var modelContext

    /// Tasks due soonest that aren't the hero item or already shown in Next Up — up to 5
    private var urgentTasks: [ChecklistTask] {
        move.tasks
            .filter { $0.status == .toDo && !$0.isHeroItem && !excludedTaskIDs.contains($0.id) }
            .sorted { $0.tMinusDays < $1.tMinusDays }
            .prefix(5)
            .map { $0 }
    }

    private var overdueTasks: [ChecklistTask] {
        let today = Date()
        return move.tasks.filter { task in
            task.status == .toDo && !task.isHeroItem && !excludedTaskIDs.contains(task.id) &&
            (Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: move.anchorDate) ?? Date()) < today
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coming Up")
                        .themeText(12, weight: .semibold)
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(2)
                    if !overdueTasks.isEmpty {
                        Text("\(overdueTasks.count) overdue")
                            .themeText(11, weight: .semibold)
                            .foregroundColor(Theme.accentPrimary)
                    }
                }
                Spacer()
                Button(action: onViewAll) {
                    HStack(spacing: 4) {
                        Text("All \(move.totalCount - move.completedCount) remaining")
                            .themeText(12, weight: .medium)
                        Image(systemName: "chevron.right")
                            .themeText(10, weight: .semibold)
                    }
                    .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            // Task cards
            if urgentTasks.isEmpty {
                Text("All tasks complete or in progress.")
                    .themeText(14)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(urgentTasks) { task in
                        UpcomingTaskRow(
                            task: task,
                            moveDate: move.anchorDate,
                            onComplete: { onTaskComplete(task) }
                        )
                        if task.id != urgentTasks.last?.id {
                            Rectangle()
                                .fill(Theme.backgroundElevated)
                                .frame(height: 0.5)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Theme.backgroundCard.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Upcoming Task Row
struct UpcomingTaskRow: View {
    let task: ChecklistTask
    let moveDate: Date
    let onComplete: () -> Void

    @State private var showingCompleteConfirmation = false

    private var dueLabel: String {
        let dueDate = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: moveDate) ?? moveDate
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                    to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
        if days < 0  { return "Overdue" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days)d"
    }

    private var isOverdue: Bool {
        let dueDate = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: moveDate) ?? moveDate
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            // Explicit checkbox — the ONLY way this row marks a task complete.
            // A row with no link used to complete on any tap, which meant an
            // accidental tap anywhere on it silently finished the task — the
            // checkbox is a small, deliberate target instead. It asks for
            // confirmation rather than completing instantly, since the only
            // prior feedback was a 4-second undo toast before the row vanished.
            Button {
                showingCompleteConfirmation = true
            } label: {
                Image(systemName: "circle")
                    .themeText(20, weight: .regular)
                    .foregroundColor(isOverdue ? Theme.priorityCritical : task.priority.color.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(task.title) complete")
            .alert("Mark as done?", isPresented: $showingCompleteConfirmation) {
                Button("Yes, it's done") { onComplete() }
                Button("Not yet", role: .cancel) {}
            } message: {
                Text("Have you updated your address or finished \"\(task.title)\"?")
            }

            // Rest of the row — only tappable (to open the link) when a link exists.
            // With no link, it's inert: informational, not an accidental "complete" trigger.
            if let url = task.deepLinkURL {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(task.institutionName ?? task.title) website")
            } else {
                rowContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            // Emoji icon
            if let emoji = task.institutionInitials, task.institutionName == nil {
                Text(emoji).themeText(20)
            } else if task.institutionName != nil {
                InstitutionBadgeView(
                    initials: task.institutionInitials ?? "?",
                    colorHex: task.institutionColorHex ?? "#626567",
                    size: 32
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .themeText(14, weight: .medium)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(task.category.rawValue)
                    .themeText(11)
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            // Due label
            Text(dueLabel)
                .themeText(11, weight: .semibold)
                .foregroundColor(isOverdue ? Theme.priorityCritical : Theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isOverdue ? Theme.priorityCritical : Color.white).opacity(0.08))
                .clipShape(Capsule())

            // Decorative link indicator — only shown (and only tappable) when a link exists
            if task.deepLinkURL != nil {
                Image(systemName: "arrow.up.right.circle.fill")
                    .themeText(18)
                    .foregroundColor(Theme.accentPrimary.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Move Timeline Section

struct MoveTimelineSection: View {
    let move: Move

    /// Generate weekly buckets from T-5 weeks to T+2 weeks
    private struct WeekBucket: Identifiable {
        let id: Int               // offset in weeks from move date
        let label: String
        let startDate: Date
        let endDate: Date
        var tasks: [ChecklistTask] = []
        let isMovWeek: Bool
        let isPast: Bool
        let isCurrent: Bool
    }

    private var buckets: [WeekBucket] {
        let cal = Calendar.current
        let moveDay = cal.startOfDay(for: move.anchorDate)
        let today = cal.startOfDay(for: Date())

        return (-5...2).map { offset in
            let start = cal.date(byAdding: .weekOfYear, value: offset, to: moveDay)!
            let end = cal.date(byAdding: .day, value: 6, to: start)!

            let label: String
            if offset == 0 {
                label = "Move\nWeek"
            } else if offset < 0 {
                label = "\(abs(offset))w\nbefore"
            } else {
                label = "\(offset)w\nafter"
            }

            let weekTasks = move.tasks.filter { task in
                guard let dueDate = cal.date(byAdding: .day, value: task.tMinusDays, to: moveDay) else { return false }
                return dueDate >= start && dueDate <= end
            }

            let isPast = end < today
            let isCurrent = today >= start && today <= end

            var bucket = WeekBucket(id: offset, label: label, startDate: start, endDate: end,
                                     isMovWeek: offset == 0, isPast: isPast, isCurrent: isCurrent)
            bucket.tasks = weekTasks
            return bucket
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move Timeline")
                .themeText(12, weight: .semibold)
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(2)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                        HStack(spacing: 0) {
                            // Connecting line
                            if index > 0 {
                                Rectangle()
                                    .fill(bucket.isPast ? Theme.accentSuccess.opacity(0.4) : Theme.backgroundElevated)
                                    .frame(width: 20, height: 2)
                                    .padding(.top, 18)
                            }

                            VStack(spacing: 6) {
                                // Week node
                                ZStack {
                                    Circle()
                                        .fill(bucket.isMovWeek ? Theme.accentPrimary :
                                              bucket.isCurrent ? Theme.accentPrimary.opacity(0.3) :
                                              bucket.isPast ? Theme.accentSuccess.opacity(0.2) :
                                              Theme.backgroundElevated)
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Circle().stroke(
                                                bucket.isMovWeek ? Theme.accentPrimary :
                                                bucket.isCurrent ? Theme.accentPrimary :
                                                Color.clear, lineWidth: 2
                                            )
                                        )

                                    if bucket.isMovWeek {
                                        Text("🏠").themeText(18)
                                    } else if bucket.isPast {
                                        Image(systemName: "checkmark")
                                            .themeText(12, weight: .bold)
                                            .foregroundColor(Theme.accentSuccess)
                                    } else {
                                        // Task count dot
                                        let pending = bucket.tasks.filter { $0.status == .toDo }.count
                                        if pending > 0 {
                                            Text("\(pending)")
                                                .themeRounded(12, weight: .bold)
                                                .foregroundColor(bucket.isCurrent ? Theme.accentPrimary : Theme.textSecondary)
                                        } else {
                                            Image(systemName: "minus")
                                                .themeText(10)
                                                .foregroundColor(Theme.textTertiary)
                                        }
                                    }
                                }

                                // Week label
                                Text(bucket.label)
                                    .themeText(9, weight: bucket.isCurrent || bucket.isMovWeek ? .bold : .regular)
                                    .foregroundColor(bucket.isMovWeek ? Theme.accentPrimary :
                                                     bucket.isCurrent ? Theme.textPrimary :
                                                     bucket.isPast ? Theme.textTertiary :
                                                     Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 48)

                                // Task category dots
                                let pendingTasks = bucket.tasks.filter { $0.status == .toDo }
                                if !pendingTasks.isEmpty && !bucket.isPast {
                                    HStack(spacing: 2) {
                                        ForEach(Array(Set(pendingTasks.compactMap { $0.poiCategory != nil ? "📍" : nil }
                                            + pendingTasks.prefix(4).map { $0.category.emoji })).prefix(4), id: \.self) { emoji in
                                            Text(emoji).themeText(8)
                                        }
                                    }
                                    .frame(width: 48)
                                }
                            }
                            .frame(width: 48)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Theme.accentSuccess.opacity(0.2)).frame(width: 8, height: 8)
                    Text("Done").themeText(10).foregroundColor(Theme.textTertiary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Theme.accentPrimary.opacity(0.3)).frame(width: 8, height: 8)
                    Text("This week").themeText(10).foregroundColor(Theme.textTertiary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Theme.backgroundElevated).frame(width: 8, height: 8)
                    Text("Upcoming").themeText(10).foregroundColor(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Achievement Milestones & Master Checklist (kept for reference, not rendered on main dashboard)

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
    @State private var selectedTask: ChecklistTask? = nil
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Achievement Milestones")
                .themeText(12, weight: .semibold)
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
                                            .themeText(20, weight: .bold)
                                            .foregroundColor(isFullyAchieved ? Theme.accentSuccess : cluster.accentColor)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cluster.title)
                                            .themeSerif(16, weight: .bold)
                                            .foregroundColor(Theme.textPrimary)

                                        Text(isFullyAchieved ? cluster.celebratoryMessage : cluster.description)
                                            .themeText(12)
                                            .foregroundColor(isFullyAchieved ? Theme.accentSuccess : Theme.textSecondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    // Progress Pill
                                    HStack(spacing: 4) {
                                        Text("\(completedTasks.count)/\(clusterTasks.count)")
                                            .themeRounded(12, weight: .bold)
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .themeText(10, weight: .bold)
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
                                            .themeText(11, weight: .bold)
                                            .foregroundColor(cluster.accentColor)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 8)

                                        ForEach(pendingTasks) { task in
                                            ZenMilestoneTaskRow(
                                                task: task,
                                                onTap: { selectedTask = task },
                                                onComplete: { completeTask(task) }
                                            )
                                        }
                                    }

                                    // Completed Section
                                    if !completedTasks.isEmpty {
                                        Text("Completed Achievements (\(completedTasks.count))")
                                            .themeText(11, weight: .bold)
                                            .foregroundColor(Theme.accentSuccess)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.top, 8)

                                        ForEach(completedTasks) { task in
                                            ZenMilestoneTaskRow(
                                                task: task,
                                                onTap: { selectedTask = task },
                                                onComplete: { completeTask(task) }
                                            )
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
        .sheet(item: $selectedTask) { task in
            TaskActionSheet(
                task: task,
                onAlreadyDone: {
                    completeTask(task)
                    selectedTask = nil
                },
                onUpdateNow: {
                    if let url = task.deepLinkURL {
                        UIApplication.shared.open(url)
                    }
                    completeTask(task)
                    selectedTask = nil
                },
                onLater: {
                    selectedTask = nil
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
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
            modelContext.saveOrLog()
        }
    }
}

// MARK: - Zen Milestone Task Row
struct ZenMilestoneTaskRow: View {
    let task: ChecklistTask
    let onTap: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Circle tap → show action sheet (or undo if already completed)
            Button(action: task.status == .completed ? onComplete : onTap) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .themeText(22, weight: .semibold)
                    .foregroundColor(task.status == .completed ? Theme.accentSuccess : Theme.textSecondary.opacity(0.5))
                    .contentShape(Rectangle())
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .themeText(15, weight: .medium)
                    .foregroundColor(task.status == .completed ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(task.status == .completed, color: Theme.textSecondary)

                HStack {
                    Text(task.category.rawValue)
                        .themeText(11)
                        .foregroundColor(Theme.textSecondary.opacity(0.6))

                    if let poi = task.poiCategory {
                        Text("• \(poi.rawValue)")
                            .themeText(11)
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                    }
                }
            }

            Spacer()

            if task.status != .completed {
                if task.actionType == .agenticUpdate {
                    Image(systemName: "sparkles")
                        .themeText(14)
                        .foregroundColor(Theme.accentPrimary)
                } else if task.deepLinkURL != nil {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .themeText(20)
                        .foregroundColor(Theme.accentPrimary.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(Theme.backgroundElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if task.status != .completed { onTap() }
        }
    }
}

// MARK: - Task Action Sheet
struct TaskActionSheet: View {
    let task: ChecklistTask
    let onAlreadyDone: () -> Void
    let onUpdateNow: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Handle + title
            VStack(alignment: .leading, spacing: 6) {
                Text("Have you updated your address?")
                    .themeText(13, weight: .regular)
                    .foregroundColor(Theme.textSecondary)
                Text("\(task.category.emoji) \(task.title)")
                    .themeSerif(20, weight: .bold)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                // Primary: already done
                Button(action: onAlreadyDone) {
                    Text("Yes, already done ✓")
                        .themeText(16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accentSuccess)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Secondary: update now (only if deep link exists)
                if task.deepLinkURL != nil {
                    Button(action: onUpdateNow) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .themeText(14, weight: .semibold)
                            Text("Update now")
                                .themeText(16, weight: .semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.backgroundElevated)
                        .foregroundColor(Theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // Tertiary: later
                Button(action: onLater) {
                    Text("I'll do this later")
                        .themeText(14, weight: .medium)
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundCard)
    }
}
