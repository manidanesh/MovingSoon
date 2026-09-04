// ZenDashboardView.swift — Brutally Minimalist Action Hub
import SwiftUI
import SwiftData
import CoreLocation
import MessageUI

struct ZenDashboardView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMailComposer = false
    @State private var selectedAgenticTask: ChecklistTask?

    // Unsplash Integration
    @State private var unsplashService = UnsplashService()
    @State private var ambientImageURL: URL?

    // Smart Location Reminders
    @State private var locationManager = LocationManager()
    @State private var consentCardDismissed = false

    // Navigation
    /// Single, atomically-set value for the All Tasks sheet — replaced a pair of
    /// separate `showingAllTasks: Bool` / `allTasksCategoryFilter: TaskCategory?`
    /// state vars set together in one Button action. `.sheet(isPresented:)` doesn't
    /// reliably observe a second @State mutation made in the same action as the one
    /// that triggers presentation — confirmed live via debug logging: the category
    /// was correctly set to `.postal` before the sheet appeared, yet the sheet
    /// rendered with no filter applied. `.sheet(item:)` on one Identifiable value
    /// removes the race by construction rather than by timing luck.
    struct AllTasksSheetContext: Identifiable {
        let id = UUID()
        var categoryFilter: TaskCategory? = nil
    }
    @State private var allTasksSheetContext: AllTasksSheetContext? = nil
    @State private var showingEditMove = false

    // Reminders
    @State private var reminderService = SmartReminderService()

    // Snoozed task IDs (persisted via snoozedUntil on the task itself)
    @State private var sessionSkippedTaskIDs: Set<UUID> = []

    // Undo support
    @State private var lastCompletedTask: ChecklistTask? = nil
    @State private var undoVisible: Bool = false
    @State private var undoTimer: Timer? = nil

    // Celebration (unused but kept for overlay compatibility)
    @State private var celebrationTask: ChecklistTask? = nil

    // MARK: - Consent card visibility predicate
    //
    // Previously gated on `daysUntilMove <= 30`, which meant the ONLY entry point to
    // grant location consent was invisible for any move more than a month out — the
    // whole geofence/location-reminder system (built, tested, working) was
    // unreachable in practice for most of a move's timeline. Removed: consent should
    // be requestable any time, not just in the final month. SuppressionEngine's own
    // gates (not this card) are what actually pace notification frequency once
    // consent is granted, so removing this doesn't risk over-notifying early.
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
        // USPS (isHeroItem) gets priority
        if let usps = pendingTasks.first(where: { $0.isHeroItem }) { return usps }
        return pendingTasks.first
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

    /// Cost-of-living delta pill next to the route — green when the destination is
    /// cheaper, amber when pricier, neutral when comparable. Nil (shows nothing) when
    /// there's no origin ZIP on file or either side falls outside RegionalEconomicsService's
    /// US snapshot (e.g. a Canadian destination).
    private var costOfLivingLabel: (text: String, color: Color)? {
        guard let comparison = move.costOfLivingComparison else { return nil }
        let pct = Int(abs(comparison.homeValueDeltaPercent).rounded())
        switch comparison.direction {
        case .costIncrease: return ("↑ \(pct)% higher cost of living", Theme.accentWarning)
        case .costDecrease: return ("↓ \(pct)% lower cost of living", Theme.accentSuccess)
        case .comparable:   return ("Similar cost of living", Theme.textTertiary)
        }
    }

    /// "78% similar region" — informational, not a value judgment, so it stays a
    /// neutral color regardless of the score (unlike the cost pill's green/amber).
    /// Nil when there's no origin ZIP on file. See RegionalSimilarityService for what
    /// this score is actually built from (and isn't — it's not a trained embedding).
    private var regionalSimilarityLabel: String? {
        guard let score = move.regionalSimilarityScore else { return nil }
        return "\(Int((score * 100).rounded()))% similar region"
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

                            // Cost-of-living delta (RegionalEconomicsService home-value comparison)
                            if let costLabel = costOfLivingLabel {
                                Text(costLabel.text)
                                    .themeText(11, weight: .medium)
                                    .foregroundColor(costLabel.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(costLabel.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            // Regional similarity (RegionalSimilarityService — WS3)
                            if let similarityLabel = regionalSimilarityLabel {
                                Text(similarityLabel)
                                    .themeText(11, weight: .medium)
                                    .foregroundColor(Theme.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.backgroundElevated.opacity(0.8))
                                    .clipShape(Capsule())
                            }

                            // Both pills above require an origin ZIP (RegionalEconomicsService.compare
                            // and RegionalSimilarityService.similarity both guard on originStateBucket).
                            // Skipping origin ZIP during onboarding is a supported path — but it silently
                            // hid two features with zero indication anything was missing. This surfaces
                            // that gap directly and routes to the exact field that unlocks it, rather
                            // than leaving the user to wonder why nothing showed up.
                            if move.originZip == nil {
                                Button { showingEditMove = true } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                            .themeText(10, weight: .semibold)
                                        Text("Add your previous ZIP for cost & lifestyle comparison")
                                    }
                                    .themeText(11, weight: .medium)
                                    .foregroundColor(Theme.accentPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.accentPrimary.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
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

                    // MARK: Categories — Home Screen-style icon tiles, grouped by
                    // urgency tier rather than a flat/expandable grid. Grouping is
                    // what keeps the grid digestible without a cap: a move with 12
                    // active categories reads as three short, scannable groups
                    // ("2 Overdue, 3 Due Soon, 7 On Track") instead of one long grid
                    // needing a "show all" toggle. Each tile carries its own category
                    // color (TaskCategory.iconGradient) — identity lives on the tile,
                    // urgency lives on the section header, and the two never conflate.
                    if !move.categoryProgressByTier.isEmpty {
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(move.categoryProgressByTier, id: \.tier) { group in
                                VStack(alignment: .leading, spacing: 14) {
                                    CategoryTierHeader(tier: group.tier, count: group.items.count)
                                        .padding(.horizontal, 24)

                                    LazyVGrid(
                                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                        spacing: 18
                                    ) {
                                        ForEach(group.items) { progress in
                                            Button {
                                                allTasksSheetContext = AllTasksSheetContext(categoryFilter: progress.category)
                                            } label: {
                                                CategoryIconTile(progress: progress)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }

                    // MARK: For Your Move (spotlight — same MoveImpactEngine
                    // suggestions AddMoreServicesView shows, surfaced here instead
                    // of requiring Settings > Edit Move > Add More Services to find)
                    if !move.moveImpactCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("For Your Move")
                                .themeText(11, weight: .semibold)
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1.5)

                            VStack(spacing: 0) {
                                ForEach(Array(move.moveImpactCandidates.prefix(2).enumerated()), id: \.element.id) { index, item in
                                    if let catalogItem = ItemCatalog.item(for: item.flag) {
                                        Button {
                                            move.lifestyleProfile?.set(item.flag, to: true)
                                            SignalEmitter.emit(item: item, accepted: true, move: move, into: modelContext)
                                            modelContext.saveOrLog()
                                        } label: {
                                            HStack(alignment: .top, spacing: 10) {
                                                Text(catalogItem.emoji)
                                                    .font(.system(size: 18))
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(catalogItem.title)
                                                        .themeText(13, weight: .semibold)
                                                        .foregroundColor(Theme.textPrimary)
                                                    Text(item.rationale)
                                                        .themeText(10.5, weight: .regular)
                                                        .foregroundColor(Theme.textSecondary)
                                                        .lineLimit(2)
                                                }
                                                Spacer()
                                                Image(systemName: "plus.circle")
                                                    .foregroundColor(Theme.accentPrimary)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)

                                        if index < min(move.moveImpactCandidates.count, 2) - 1 {
                                            Divider().background(Theme.backgroundElevated)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                LinearGradient(colors: [Theme.accentPrimary.opacity(0.16), Theme.backgroundCard],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentPrimary.opacity(0.35), lineWidth: 1))

                            if move.moveImpactCandidates.count > 2 {
                                Button { showingEditMove = true } label: {
                                    Text("See \(move.moveImpactCandidates.count - 2) more suggestion\(move.moveImpactCandidates.count - 2 == 1 ? "" : "s")")
                                        .themeText(11, weight: .medium)
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

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

                    // MARK: Location Reminders Visibility
                    // Previously a fully silent background system — consent granted or
                    // not, nothing on screen ever showed what it was actually watching
                    // for. This makes it inspectable: which place types near the
                    // destination will trigger a nudge, once you're actually near one.
                    if move.locationConsentGrantedAt != nil, !move.trackedPOICategories.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "location.fill")
                                .themeText(13, weight: .semibold)
                                .foregroundColor(Theme.accentPrimary)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Watching Nearby")
                                    .themeText(11, weight: .semibold)
                                    .foregroundColor(Theme.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                Text("We'll nudge you when you're near a " +
                                     move.trackedPOICategories.map(\.displayName).joined(separator: ", "))
                                    .themeText(12, weight: .regular)
                                    .foregroundColor(Theme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(Theme.backgroundElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
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
                            onUpdateNow: {
                                // Opens the link but doesn't mark complete — matches
                                // Hero Card's Update Now, which only starts the process.
                                // Dismiss the prompt; it's served its purpose once acted on.
                                locationManager.activeContextualTask = nil
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
                                onSkip: { skipTask(hero) },
                                onNotApplicable: { removeTaskNotApplicable(hero) }
                            )
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                        }
                    }

                    // MARK: Up Next — single ranked list, replacing the old Next Up /
                    // Coming Up split (see UpNextSection's header comment for why).
                    UpNextSection(
                        move: move,
                        excludedTaskIDs: Set([heroTask?.id].compactMap { $0 }),
                        onTaskComplete: { task in completeTask(task) },
                        onTaskRemoved: { _ in resyncNotificationsAndGeofences() },
                        onViewAll: { allTasksSheetContext = AllTasksSheetContext() }
                    )

                    // MARK: Move Timeline — when do things need to happen
                    MoveTimelineSection(move: move)

                    // MARK: Achievement Milestones — same tasks as the tiles/Up Next
                    // above, regrouped into 5 broader lifestyle themes with a
                    // gamified "fully cleared" celebration. A complementary view,
                    // not competing with the primary do-this-next flow above it.
                    AchievementMilestoneSection(
                        move: move,
                        onTaskComplete: { task in completeTask(task) },
                        onNotApplicable: { task in removeTaskNotApplicable(task) }
                    )

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
        .sheet(item: $allTasksSheetContext) { context in
            NavigationStack {
                DashboardView(
                    move: move,
                    categoryFilter: context.categoryFilter,
                    onTaskRemoved: { _ in resyncNotificationsAndGeofences() }
                )
                    .navigationTitle(context.categoryFilter?.rawValue ?? "All Tasks")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { allTasksSheetContext = nil }
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
            // Live location is only needed for the foreground "near a task right now"
            // banner — geofence entries fire independently via region monitoring.
            locationManager.startForegroundUpdates()
            // Ask for notification permission here, contextually — once the user has reached
            // their dashboard and reminders are actually about to be scheduled — rather than
            // at cold launch before onboarding, where there's no reason yet to say yes.
            // TEMPORARY: skipped during screenshot seeding so the system prompt doesn't
            // cover the dashboard in captures. Remove alongside the other seed-flag checks.
            if ProcessInfo.processInfo.environment["SEED_SCREENSHOT_DATA"] != "1" {
                reminderService.requestPermissions()
            }
            // Schedule hero task daily reminder
            reminderService.scheduleHeroTaskReminder(heroTask: heroTask)
            // Schedule T-minus reminders for tasks due in 3 days
            reminderService.scheduleTMinusReminders(tasks: move.tasks, moveDate: move.anchorDate)
        }
        .onChange(of: heroTask?.id) { _, _ in
            reminderService.scheduleHeroTaskReminder(heroTask: heroTask)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Stop continuous GPS the moment the app leaves the foreground — geofence
            // entries still fire via region monitoring while backgrounded/suspended.
            if newPhase == .active {
                locationManager.startForegroundUpdates()
            } else {
                locationManager.stopForegroundUpdates()
            }
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

    /// A real deletion, not a status change — the task is gone from move.tasks
    /// and the SwiftData store, so it can't resurface as the hero task, in Up
    /// Next, or in category progress counts, all of which re-derive their list
    /// from move.tasks live. Confirmed via ZenHeroCard's confirmationDialog
    /// before this ever runs. Local notifications and geofences are a separate
    /// concern — they're OS-level state scheduled with baked-in content, not
    /// re-derived on read — so resyncNotificationsAndGeofences() below handles
    /// those explicitly.
    private func removeTaskNotApplicable(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            move.tasks.removeAll { $0.id == task.id }
            modelContext.delete(task)
            modelContext.saveOrLog()
        }
        resyncNotificationsAndGeofences()
    }

    /// Re-derives the T-minus digest queue and geofence regions from the current
    /// move.tasks. Needed after any deletion: scheduleTMinusReminders() bakes
    /// task names into notification content at schedule time and only otherwise
    /// runs once at dashboard load, so a removed task's name can linger in an
    /// already-queued notification, and a removed task's geofence region keeps
    /// being monitored, until this runs. (The hero reminder doesn't need this —
    /// it already re-schedules reactively via .onChange(of: heroTask?.id).)
    private func resyncNotificationsAndGeofences() {
        reminderService.scheduleTMinusReminders(tasks: move.tasks, moveDate: move.anchorDate)
        locationManager.syncGeofencesIfActive()
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

// MARK: - Category Tier Header
//
// One header per urgency tier (Overdue / Due Soon / On Track), colored to match
// the tier's severity. This is where urgency lives now — the tiles beneath it
// carry category identity only, never severity, so the two signals never fight
// for the same pixel.
struct CategoryTierHeader: View {
    let tier: CategoryUrgencyTier
    let count: Int

    private var color: Color {
        switch tier {
        case .overdue: return Theme.priorityCritical
        case .dueSoon: return Theme.accentWarning
        case .onTrack: return Theme.accentSuccess
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(tier.rawValue)
                .themeText(12, weight: .bold)
                .foregroundColor(color)
                .textCase(.uppercase)
                .tracking(1.2)
            Text("\(count)")
                .themeText(12, weight: .semibold)
                .foregroundColor(color.opacity(0.7))
            Rectangle()
                .fill(color.opacity(0.25))
                .frame(height: 1)
        }
    }
}

// MARK: - Category Icon Tile
//
// iOS Home Screen icon convention, applied to categories: a fixed-color squircle
// per category (TaskCategory.iconGradient) with an SF Symbol glyph, a soft top
// highlight sheen like a real app icon, and a red count badge in the corner that
// disappears entirely once nothing's left — the same "no badge = nothing
// outstanding" signal every iPhone user already reads from their Home Screen.
// No card container: tiles float on the dashboard background the way Home
// Screen icons float on wallpaper, which is most of what makes this read as
// smaller/lighter than the old card grid despite the icon itself being bigger.
struct CategoryIconTile: View {
    let progress: CategoryProgress

    private var remaining: Int { progress.total - progress.completed }
    private var gradient: (top: Color, bottom: Color) { progress.category.iconGradient }

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [gradient.top, gradient.bottom], startPoint: .top, endPoint: .bottom))
                    .frame(width: 58, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        Image(systemName: progress.category.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .shadow(color: gradient.bottom.opacity(0.35), radius: 6, x: 0, y: 3)

                if remaining > 0 {
                    Text("\(remaining)")
                        .themeText(11, weight: .bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, remaining > 9 ? 5 : 0)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Theme.priorityCritical, in: Circle())
                        .overlay(Circle().stroke(Theme.backgroundPrimary, lineWidth: 2))
                        .offset(x: 8, y: -8)
                }
            }

            Text(progress.category.rawValue)
                .themeText(12.5, weight: .semibold)
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Zen Hero Card
struct ZenHeroCard: View {
    let task: ChecklistTask
    let onComplete: () -> Void
    let onAgenticAction: () -> Void
    let onSkip: () -> Void
    /// Permanently removes the task — see TaskActionSheet's onNotApplicable for
    /// why catalog tasks (Mathnasium, Goldfish Swim School, etc.) need this: a
    /// broad lifestyle flag can put an irrelevant task in front of any user, and
    /// once one lands here as the most urgent thing, it needs a real way out.
    let onNotApplicable: () -> Void

    @State private var showingRemoveConfirm = false

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

                        // Secondary: already done. Green = "confirmed done," everywhere
                        // in the app — never blue, which is reserved for "take the
                        // external action." See MoveImpactEngine-adjacent surfaces for
                        // the same rule applied consistently.
                        Button(action: onComplete) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .themeText(13, weight: .bold)
                                Text("Mark as Done")
                                    .themeText(15, weight: .semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.backgroundElevated)
                            .foregroundColor(Theme.accentSuccess)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // No deep link — this task was never going to have an "Update
                        // Now" option, so "Mark as Done" is the only action here. It
                        // still gets accentSuccess (green), not accentPrimary (blue) —
                        // "done" is "done" regardless of whether a link exists.
                        Button(action: onComplete) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .themeText(14, weight: .bold)
                                Text("Mark as Done")
                                    .themeText(16, weight: .bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.accentSuccess)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Theme.accentSuccess.opacity(0.35), radius: 10, x: 0, y: 4)
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

                    // Destructive: not applicable to this user at all — distinct
                    // from "remind me later" (still relevant, just not now).
                    Button {
                        showingRemoveConfirm = true
                    } label: {
                        Text("Not Applicable")
                            .themeText(13, weight: .medium)
                            .foregroundColor(Theme.priorityCritical.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .confirmationDialog(
            "Remove \"\(task.title)\"?",
            isPresented: $showingRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: onNotApplicable)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won't be shown again. This can't be undone.")
        }
    }
}

// MARK: - Contextual Prompt Card
struct ContextualPromptCard: View {
    let task: ChecklistTask
    let onYes: () -> Void
    let onRemindTomorrow: () -> Void
    var onUpdateNow: (() -> Void)? = nil

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

                VStack(spacing: 10) {
                    // Primary: confirm done. Green — the same "confirmed done" color
                    // used everywhere else in the app, not blue (blue is reserved for
                    // "take the external action," below). Primary here, not secondary,
                    // because this prompt only fires when the user is physically near
                    // the place — the likely case is they just handled it.
                    Button(action: onYes) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .themeText(14, weight: .bold)
                            Text("Mark as Done")
                                .themeText(15, weight: .bold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accentSuccess, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        // Previously missing entirely — if the user hasn't actually
                        // done this yet, there was no way to act on the prompt itself.
                        if let url = task.deepLinkURL, let onUpdateNow {
                            Button {
                                UIApplication.shared.open(url)
                                onUpdateNow()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right")
                                        .themeText(12, weight: .bold)
                                    Text("Update Now")
                                        .themeText(14, weight: .semibold)
                                }
                                .foregroundColor(Theme.accentPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: onRemindTomorrow) {
                            Text("Remind Tomorrow")
                                .themeText(14, weight: .semibold)
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.backgroundElevated, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Up Next Section
//
// Formerly two sections — "Next Up" (ranks 2-3 of the pending-task list) and
// "Coming Up" / TodaysPrioritiesSection (ranks 4-8) — that were never actually
// distinct: both drew from the identical tMinusDays sort, split at an arbitrary
// count. Merged into one list, one row style (UpcomingTaskRow, which already had
// the richer detail — due date, checkbox, TaskActionSheet — the other section
// lacked). ZenDrawerRow and the tap-to-promote-to-hero interaction it carried are
// retired along with it; nothing downstream depended on either.
struct UpNextSection: View {
    let move: Move
    /// Just the hero task's id — this section now owns everything else.
    let excludedTaskIDs: Set<UUID>
    let onTaskComplete: (ChecklistTask) -> Void
    /// Fired after a task is deleted (Not Applicable) so the parent can resync
    /// notifications/geofences — this section doesn't own reminderService or
    /// locationManager itself. See ZenDashboardView.resyncNotificationsAndGeofences.
    let onTaskRemoved: (ChecklistTask) -> Void
    let onViewAll: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTask: ChecklistTask? = nil

    /// Tasks due soonest that aren't the hero item — up to 6 (previously 2 in "Next
    /// Up" + 5 in "Coming Up" = 7 visible without tapping through; 6 keeps that same
    /// ballpark as one continuous list instead of two visually separate blocks).
    private var urgentTasks: [ChecklistTask] {
        move.tasks
            .filter { $0.status == .toDo && !$0.isHeroItem && !excludedTaskIDs.contains($0.id) }
            .sorted { $0.tMinusDays < $1.tMinusDays }
            .prefix(6)
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
                    Text("Up Next")
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
                            // Opens the detail/confirm sheet rather than completing
                            // instantly — a bare checkbox tap gave no way to see what
                            // the task actually was, or choose "take the action" vs.
                            // "confirm it's already done," before finishing it.
                            onTap: { selectedTask = task }
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
        .sheet(item: $selectedTask) { task in
            TaskActionSheet(
                task: task,
                onAlreadyDone: {
                    onTaskComplete(task)
                    selectedTask = nil
                },
                onUpdateNow: {
                    // Opens the link only — does not auto-complete, matching Hero
                    // Card's Update Now, which likewise only starts the process.
                    if let url = task.deepLinkURL {
                        UIApplication.shared.open(url)
                    }
                    selectedTask = nil
                },
                onLater: { selectedTask = nil },
                onNotApplicable: {
                    removeTaskNotApplicable(task)
                    selectedTask = nil
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    /// See ZenDashboardView.removeTaskNotApplicable — same real-deletion contract,
    /// duplicated here because this section owns its own `move`/`modelContext`
    /// rather than reaching back up to the parent view.
    private func removeTaskNotApplicable(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            move.tasks.removeAll { $0.id == task.id }
            modelContext.delete(task)
            modelContext.saveOrLog()
        }
        onTaskRemoved(task)
    }
}

// MARK: - Upcoming Task Row
struct UpcomingTaskRow: View {
    let task: ChecklistTask
    let moveDate: Date
    let onTap: () -> Void

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

    /// Escalating severity: overdue (red) > due within 3 days (amber) > everything
    /// else (neutral). Previously this row only had two states — overdue or not —
    /// so a task due tomorrow looked exactly as calm as one due in six weeks.
    private var isDueSoon: Bool {
        guard !isOverdue else { return false }
        let dueDate = Calendar.current.date(byAdding: .day, value: task.tMinusDays, to: moveDate) ?? moveDate
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                    to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
        return days <= 3
    }

    private var severityColor: Color {
        if isOverdue { return Theme.priorityCritical }
        if isDueSoon { return Theme.accentWarning }
        return task.priority.color.opacity(0.5)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Status only — not a button. A circle signifies "tap this to toggle
            // directly," same as Reminders/Things; using that shape to trigger a
            // 3-choice menu instead breaks that trained mapping. The row itself is
            // the call to action (below), so the circle just shows state.
            Image(systemName: "circle")
                .themeText(20, weight: .regular)
                .foregroundColor(severityColor)
                .accessibilityHidden(true)

            rowContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Open \(task.title)")
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

            // Due label — same escalating severity as the checkbox
            Text(dueLabel)
                .themeText(11, weight: .semibold)
                .foregroundColor(isOverdue ? Theme.priorityCritical : isDueSoon ? Theme.accentWarning : Theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (isOverdue ? Theme.priorityCritical : isDueSoon ? Theme.accentWarning : Color.white)
                        .opacity(isOverdue || isDueSoon ? 0.14 : 0.08)
                )
                .clipShape(Capsule())

            // Decorative — hints a link exists; the whole row is the tap target (opens
            // the action sheet), not this icon specifically.
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
    /// Reuses the parent's completeTask/removeTaskNotApplicable rather than owning
    /// local copies — this section previously had its own completeTask that skipped
    /// the toDo → pendingVerification → completed double-advance, so "Mark as Done"
    /// left tasks stuck showing as pending instead of moving to Completed Achievements.
    let onTaskComplete: (ChecklistTask) -> Void
    let onNotApplicable: (ChecklistTask) -> Void
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
                                                onComplete: { undoCompletion(task) }
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
                                                onComplete: { undoCompletion(task) }
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
                    onTaskComplete(task)
                    selectedTask = nil
                },
                onUpdateNow: {
                    // Opens the link only — does not auto-complete, matching every
                    // other Update Now in the app (Hero Card, Up Next, All Tasks).
                    if let url = task.deepLinkURL {
                        UIApplication.shared.open(url)
                    }
                    selectedTask = nil
                },
                onLater: {
                    selectedTask = nil
                },
                onNotApplicable: {
                    onNotApplicable(task)
                    selectedTask = nil
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    /// ZenMilestoneTaskRow's checkmark tap is exclusively an undo — the parent's
    /// onTaskComplete is one-way (advanceStatus() no-ops on an already-completed
    /// task), so it can't handle this. Kept local since "tap checkmark to undo"
    /// is specific to this row/section, not shared elsewhere.
    private func undoCompletion(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation {
            task.resetStatus()
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
            // Pending: status only, not a button — the whole row is the call to
            // action (onTapGesture below), so the circle shouldn't also masquerade
            // as a second, checkbox-shaped trigger for the same menu. Completed:
            // the checkmark stays a real, direct toggle (undo), which a checkbox
            // shape correctly signifies.
            if task.status == .completed {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .themeText(22, weight: .semibold)
                        .foregroundColor(Theme.accentSuccess)
                        .contentShape(Rectangle())
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(task.title) not complete")
            } else {
                Image(systemName: "circle")
                    .themeText(22, weight: .semibold)
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }

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
        // Only the pending row folds into one VoiceOver stop (it's a single button
        // now). Completed rows leave the nested undo button reachable on its own —
        // combining here would swallow it.
        .modifier(CombinedAccessibilityIfPending(task: task))
    }
}

/// Shared by every task row that puts the action-sheet trigger on the whole row
/// instead of the leading circle (UnifiedTaskRow in DashboardView.swift is the
/// other user): only the pending row folds into one VoiceOver stop, since it's
/// a single button now. Completed rows leave their nested undo button reachable
/// on its own — combining here would swallow it.
struct CombinedAccessibilityIfPending: ViewModifier {
    let task: ChecklistTask

    func body(content: Content) -> some View {
        if task.status == .completed {
            content
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Open \(task.title)")
        }
    }
}

// MARK: - Task Action Sheet
struct TaskActionSheet: View {
    let task: ChecklistTask
    let onAlreadyDone: () -> Void
    let onUpdateNow: () -> Void
    let onLater: () -> Void
    /// Permanently removes the task from the move — not a status, an actual
    /// deletion (see the confirmation copy below). Catalog-generated tasks like
    /// "Mathnasium — Update Account" or "Goldfish Swim School" are matched from
    /// broad lifestyle flags (e.g. "has children") that can't know which specific
    /// activities a family actually uses, so a wrong match needs a real way to
    /// leave and never come back — not just a snooze.
    let onNotApplicable: () -> Void

    @State private var showingRemoveConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Handle + title
            VStack(alignment: .leading, spacing: 6) {
                Text(task.category.rawValue)
                    .themeText(11, weight: .semibold)
                    .foregroundColor(Theme.accentPrimary)
                    .textCase(.uppercase)
                    .tracking(1.5)
                Text("\(task.category.emoji) \(task.title)")
                    .themeSerif(20, weight: .bold)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                // Primary: take the action, if there's a link to take it with —
                // matches Hero Card's hierarchy (Update Now leads when possible).
                // Blue = "take the external action" everywhere in this app.
                if task.deepLinkURL != nil {
                    Button(action: onUpdateNow) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .themeText(14, weight: .bold)
                            Text("Update Now")
                                .themeText(16, weight: .bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accentPrimary)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // Confirm done. Green = "confirmed done" everywhere in this app —
                // the same color law as Hero Card and the geofence prompt.
                Button(action: onAlreadyDone) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .themeText(14, weight: .bold)
                        Text("Mark as Done")
                            .themeText(16, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(task.deepLinkURL != nil ? Theme.backgroundElevated : Theme.accentSuccess)
                    .foregroundColor(task.deepLinkURL != nil ? Theme.accentSuccess : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Tertiary: later
                Button(action: onLater) {
                    Text("I'll do this later")
                        .themeText(14, weight: .medium)
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                // Destructive: not applicable to this user at all — distinct from
                // "later" (still on the list, just deferred). Tinted, not filled,
                // so it doesn't compete visually with Update Now / Mark as Done.
                Button {
                    showingRemoveConfirm = true
                } label: {
                    Text("Not Applicable")
                        .themeText(13, weight: .medium)
                        .foregroundColor(Theme.priorityCritical.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundCard)
        .confirmationDialog(
            "Remove \"\(task.title)\"?",
            isPresented: $showingRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: onNotApplicable)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won't be shown again. This can't be undone.")
        }
    }
}
