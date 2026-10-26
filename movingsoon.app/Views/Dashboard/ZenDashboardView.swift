// ZenDashboardView.swift — Brutally Minimalist Action Hub
import SwiftUI
import SwiftData
import CoreLocation
import MessageUI
import StoreKit

struct ZenDashboardView: View {
    let move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingMailComposer = false
    @State private var selectedAgenticTask: ChecklistTask?


    // Aggregate Census context for the entered postal areas. This is distinct from
    // the user's self-reported LifestyleProfile and is never used as a household fact.
    @State private var areaMarketComparison: AreaMarketComparison?
    @State private var isLoadingAreaMarketComparison = false
    @State private var areaMarketUnavailableMessage: String?
    @State private var moveFitTaskAdded = false
    @State private var areaRefreshID = 0

    // Smart Location Reminders
    @State private var locationManager = LocationManager.shared
    @State private var consentCardDismissed = false
    @State private var alwaysUpgradeCardDismissed = false
    @State private var dismissedRenewalWindow: String?

    // Notification tap routing — see NotificationRouter for why this can't be handled
    // directly by NotificationDelegate.
    private let notificationRouter = NotificationRouter.shared
    @State private var notificationActionTask: ChecklistTask?

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
    @State private var showingReminders = false
    #if DEBUG
    @State private var screenshotCatalogItem: CatalogItem?
    @State private var screenshotLibrary = false
    #endif
    @State private var showingAddMoreServices = false

    // Reminders
    @State private var reminderService = SmartReminderService.shared

    // Snoozed task IDs (persisted via snoozedUntil on the task itself)
    @State private var sessionSkippedTaskIDs: Set<UUID> = []

    // Undo support
    @State private var lastCompletedTask: ChecklistTask? = nil
    @State private var undoVisible: Bool = false
    @State private var undoTimer: Timer? = nil

    // "Not Applicable" undo support — same grace-period shape as completion above
    @State private var lastRemovedTask: ChecklistTask? = nil
    @State private var lastRemovedResponse: ServiceResponse? = nil
    @State private var removeUndoVisible: Bool = false
    @State private var removeUndoTimer: Timer? = nil

    // Whole-move completion finale — fires once per move (see Move.completionCelebratedAt)
    @State private var showingCompletionCelebration = false

    private var shouldShowConsentCard: Bool {
        ReminderPolicy.showsConsent(grantedAt: move.locationConsentGrantedAt,
            status: locationManager.authorizationStatus, dismissed: consentCardDismissed)
    }

    private var needsAlwaysUpgrade: Bool {
        ReminderPolicy.needsAlwaysUpgrade(grantedAt: move.locationConsentGrantedAt,
            status: locationManager.authorizationStatus, dismissed: alwaysUpgradeCardDismissed)
    }

    private var renewalWindowID: String {
        "\(move.id.uuidString)|\(move.locationConsentGrantedAt?.timeIntervalSince1970 ?? 0)"
    }

    private var locationConsentRenewalPrompt: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if ReminderPolicy.shouldOfferConsentRenewal(for: move, now: context.date),
               dismissedRenewalWindow != renewalWindowID {
                LocationConsentRenewalCard(
                    onReview: { showingReminders = true },
                    onDismiss: { dismissedRenewalWindow = renewalWindowID },
                    completionPaused: move.completionFraction >= 0.80
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private var locationReminderStatus: String {
        if !locationManager.consentActive { return "30-day location reminders have ended" }
        if !locationManager.backgroundRemindersEnabled { return "Finish location setup below" }
        if !reminderService.isAuthorized { return "Notifications are off" }
        if locationManager.geofenceCoordinator.registeredRegionIDs.isEmpty { return "No nearby provider locations matched yet" }
        return "Nearby reminders are on"
    }

    // Account dates can bring the move-relative address review forward.
    private var pendingTasks: [ChecklistTask] {
        let now = Date()
        return move.tasks
            .filter {
                $0.status == .toDo &&
                !sessionSkippedTaskIDs.contains($0.id) &&
                ($0.snoozedUntil == nil || $0.snoozedUntil! < now)
            }
            .sorted { $0.isDueBefore($1, moveDate: move.effectiveAnchorDate) }
    }

    private var heroTask: ChecklistTask? {
        guard let earliest = pendingTasks.first else { return nil }
        guard let preferred = pendingTasks.first(where: { $0.isHeroItem }) else { return earliest }
        return earliest.dueDate(moveDate: move.effectiveAnchorDate) < preferred.dueDate(moveDate: move.effectiveAnchorDate)
            ? earliest : preferred
    }

    private var daysUntilMoveLabel: String {
        let days = move.daysUntilMove
        if days > 0  { return "T-Minus \(days) Days" }
        if days == 0 { return "Moving Day 🎉" }
        return "Day \(abs(days)) in your new home"
    }

    /// Include account deadlines as well as ordinary move-relative due dates.
    private var overdueCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return move.tasks.filter { task in
            guard task.status == .toDo else { return false }
            let due = task.dueDate(moveDate: move.effectiveAnchorDate, calendar: Calendar.current)
            return Calendar.current.startOfDay(for: due) < today
        }.count
    }

    /// Count tasks due within the next 7 days
    private var dueThisWeekCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return 0 }
        return move.tasks.filter { task in
            guard task.status == .toDo else { return false }
            let due = task.dueDate(moveDate: move.effectiveAnchorDate, calendar: Calendar.current)
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

    /// State median home-value delta. This is not a full cost-of-living comparison.
    /// Nil (shows nothing) when
    /// there's no origin ZIP on file or either side falls outside RegionalEconomicsService's
    /// US snapshot (e.g. a Canadian destination).
    private var costOfLivingLabel: (text: String, color: Color)? {
        guard let comparison = move.costOfLivingComparison else { return nil }
        let pct = Int(abs(comparison.homeValueDeltaPercent).rounded())
        switch comparison.direction {
        case .costIncrease: return ("State home values ~\(pct)% higher", Theme.textSecondary)
        case .costDecrease: return ("State home values ~\(pct)% lower", Theme.textSecondary)
        case .comparable:   return ("Similar state home values", Theme.textTertiary)
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

    private var moveFitHousingMeasure: MoveFitHousingMeasure? {
        guard let comparison = areaMarketComparison,
              let flags = move.lifestyleProfile?.activeFlags else { return nil }
        return MoveFitEngine.housingMeasure(comparison: comparison, flags: flags)
    }

    private var moveFitHomeValueMeasure: MoveFitHousingMeasure? {
        guard let comparison = areaMarketComparison else { return nil }
        return MoveFitEngine.homeValueMeasure(comparison: comparison)
    }

    private var moveFitTaskTitle: String? {
        guard let measure = moveFitHousingMeasure else { return nil }
        return measure.title == "Median gross rent"
            ? "Compare destination-area rent with my budget"
            : "Compare destination-area owner costs with my budget"
    }

    @MainActor
    private func addMoveFitBudgetTask() {
        guard let title = moveFitTaskTitle,
              !move.tasks.contains(where: { $0.title == title }) else {
            moveFitTaskAdded = true
            return
        }
        let task = ChecklistTask(title: title, category: .other, priority: .medium,
                                 tMinusDays: -14, isUserAdded: true)
        task.move = move
        task.setCustomDueDate(task.baseDueDate(moveDate: move.effectiveAnchorDate))
        modelContext.insert(task)
        move.tasks.append(task)
        guard modelContext.saveOrLog() else { return }
        reminderService.reschedule(for: move)
        moveFitTaskAdded = true
    }

    @MainActor
    private func loadAreaMarketComparison(refresh: Bool = false) async {
        areaMarketComparison = nil
        areaMarketUnavailableMessage = nil
        guard move.areaInsightsEnabled == true else {
            isLoadingAreaMarketComparison = false
            return
        }
        guard PostalCodeService.regionalFlags(for: move.destinationZip).contains(.isAmerican) else {
            areaMarketUnavailableMessage = "US Census area estimates aren’t available for Canadian postal codes yet."
            isLoadingAreaMarketComparison = false
            return
        }
        isLoadingAreaMarketComparison = true
        let originZIP = move.originZip ?? ""
        let destinationZIP = move.destinationZip
        async let originRequest = AreaMarketDataService.profile(for: originZIP, refresh: refresh)
        async let destinationRequest = AreaMarketDataService.profile(for: destinationZIP, refresh: refresh)
        let (origin, destination) = await (originRequest, destinationRequest)
        guard !Task.isCancelled, move.areaInsightsEnabled == true,
              originZIP == (move.originZip ?? ""), destinationZIP == move.destinationZip else { return }
        areaMarketComparison = destination.map {
            AreaMarketComparison(origin: origin, destination: $0)
        }
        if destination == nil {
            areaMarketUnavailableMessage = "We couldn’t load estimates for this destination ZIP. Connect to the internet and try again."
        }
        isLoadingAreaMarketComparison = false
    }

    @ViewBuilder private var nextActionSection: some View {
        if let hero = heroTask {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your next step")
                    .themeText(12, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 24)
                ZenHeroCard(task: hero,
                    onComplete: { completeTask(hero) },
                    onAgenticAction: { triggerAgenticAction(for: hero) },
                    onSkip: { skipTask(hero) },
                    onNotApplicable: { removeTaskNotApplicable(hero) })
                    .padding(.horizontal, 20)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(move.allTasksCompleted ? "Your checklist is complete." : "Nothing to do right now.")
                    .themeSerif(26, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text(move.allTasksCompleted
                     ? "Take a breath. You can still review categories for anything you may have missed."
                     : "\(move.unfinishedCount) items remain, including \(move.snoozedCount) snoozed. Your progress is saved.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                if let next = move.tasks.filter({ $0.status != .completed })
                    .compactMap(\.snoozedUntil).filter({ $0 > Date() }).min() {
                    Text("Next snoozed item returns \(next.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Button("View all tasks") { allTasksSheetContext = AllTasksSheetContext() }
                    .foregroundStyle(Theme.accentPrimary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)
        }
    }

    private var areaInsightsSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Optional US Census estimates compare your ZIP areas. Enabling this sends the entered ZIP codes to the Census API. Your household answers stay on this device.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                Toggle("Use ZIP area estimates", isOn: Binding(
                    get: { move.areaInsightsEnabled == true },
                    set: { enabled in
                        move.areaInsightsEnabled = enabled
                        if !enabled { areaMarketComparison = nil }
                        modelContext.saveOrLog()
                    }))
                if move.areaInsightsEnabled == true {
                    if isLoadingAreaMarketComparison {
                        ProgressView("Loading area estimates…")
                    } else if let comparison = areaMarketComparison {
                        AreaMarketSnapshotCard(comparison: comparison,
                            originLabel: move.originZip.map { "ZIP \($0) area" } ?? "Previous area",
                            destinationLabel: "ZIP \(move.destinationZip) area",
                            originWasProvided: move.originZip != nil)
                        AreaIncomeDistributionView(comparison: comparison)
                        if Date().timeIntervalSince(comparison.destination.retrievedAt) >= 30 * 86400 {
                            Text("This saved snapshot is over 30 days old. Refresh when connected to check for updated estimates.")
                                .font(.caption).foregroundStyle(Theme.accentWarning)
                        }
                        Text("Destination snapshot saved \(comparison.destination.retrievedAt.formatted(date: .abbreviated, time: .omitted)). Cached estimates remain available offline.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                        if let measure = moveFitHousingMeasure {
                            MoveFitHousingCard(measure: measure,
                                homeValueMeasure: moveFitHomeValueMeasure,
                                originLabel: move.originZip.map { "ZIP \($0) area" } ?? "Previous area",
                                destinationLabel: "ZIP \(move.destinationZip) area",
                                taskAdded: moveFitTaskTitle.map { title in move.tasks.contains { $0.title == title } } ?? false,
                                onAddBudgetCheck: addMoveFitBudgetTask)
                        }
                    } else if let message = areaMarketUnavailableMessage {
                        Text(message).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Button("Refresh estimates") { areaRefreshID += 1 }
                        .disabled(isLoadingAreaMarketComparison)
                    Text("Area averages do not establish your income, home value or service memberships.")
                        .font(.caption).foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.top, 12)
        } label: {
            Label("Explore your new area", systemImage: "map")
                .font(.headline).foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accentPrimary)
        .padding(18)
        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private var dashboardContent: some View {
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
                                .fixedSize(horizontal: false, vertical: true)

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
                                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                                        .truncationMode(.middle)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.backgroundElevated.opacity(0.8))
                                .clipShape(Capsule())
                            }

                            // State median home-value delta (not a full cost-of-living measure).
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
                            } else if move.completedCount > 0, move.totalCount > move.completedCount {
                                // Loss-aversion framing once there's real progress to protect —
                                // a bare percentage doesn't give the user anything to lose.
                                Text("\(move.completedCount) of \(move.totalCount) done — don't let the last \(move.totalCount - move.completedCount) slip")
                                    .themeText(13, weight: .regular)
                                    .foregroundColor(Theme.textSecondary)
                            } else {
                                Text("\(Int(move.completionFraction * 100))% complete")
                                    .themeText(13, weight: .regular)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()

                        // Text elsewhere carries the progress at accessibility sizes.
                        if !typeSize.isAccessibilitySize {
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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(move.completedCount) of \(move.totalCount) tasks completed")
                        }

                        // Settings button
                        Button { showingEditMove = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Theme.backgroundElevated, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Move settings")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Button { showingReminders = true } label: {
                        Label("Reminders", systemImage: "bell")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24)
                    }
                    nextActionSection

                    if move.tasks.contains(where: { $0.needsLocationReview == true && $0.status != .completed }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your locations changed")
                                .font(.headline).foregroundStyle(Theme.textPrimary)
                            Text("Some earlier tasks belong to a different area. Open them to confirm they still apply or remove them. Your completed work is kept.")
                                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                            Button("Review earlier tasks") { allTasksSheetContext = AllTasksSheetContext() }
                        }
                        .padding(18)
                        .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 20)
                    }

                    ForgottenItemsCard(move: move, area: areaMarketComparison,
                        onReview: { showingAddMoreServices = true },
                        onChanged: resyncNotificationsAndGeofences)
                        .padding(.horizontal, 20)

                    UpNextSection(
                        move: move,
                        excludedTaskIDs: Set([heroTask?.id].compactMap { $0 }),
                        onTaskComplete: { task in completeTask(task) },
                        onTaskRemoved: { _ in resyncNotificationsAndGeofences() },
                        onViewAll: { allTasksSheetContext = AllTasksSheetContext() }
                    )

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
                                        columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 1 : 3),
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

                    areaInsightsSection
                        .padding(.horizontal, 20)

                    // MARK: Location Consent Card
                    if shouldShowConsentCard {
                        LocationConsentCard(
                            onAllow: {
                                locationManager.attach(move, context: modelContext)
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

                    locationConsentRenewalPrompt

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
                                Text(locationReminderStatus)
                                    .themeText(11, weight: .semibold)
                                    .foregroundColor(Theme.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                Text("Nearby reminders use matching providers from your checklist. General accounts without a known provider keep their scheduled reminders.")
                                    .themeText(12, weight: .regular)
                                    .foregroundColor(Theme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !reminderService.isAuthorized {
                                    Button("Notification settings") {
                                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                    }.font(.caption)
                                }
                                if locationManager.consentActive && !locationManager.backgroundRemindersEnabled {
                                    Button("Location settings") {
                                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                    }.font(.caption)
                                }
                            }
                        }
                        .padding(14)
                        .background(Theme.backgroundElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }

                    // MARK: Always-Upgrade Nudge
                    if needsAlwaysUpgrade {
                        LocationAlwaysUpgradeCard(onDismiss: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                alwaysUpgradeCardDismissed = true
                            }
                        })
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

                    LinearGradient(
                        colors: [Theme.backgroundPrimary.opacity(0.85), Theme.backgroundPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            }
        }
    }

    private var dashboardSheets: some View {
        dashboardContent
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingMailComposer, onDismiss: resumePendingReminderRoute) {
            if let task = selectedAgenticTask {
                MailComposeView(
                    toRecipients: [],
                    subject: "Address Change Request: \(task.title)",
                    messageBody: "Hello,\n\nPlease update my address on file to my new location.\n\nThank you.",
                    isShowing: $showingMailComposer
                )
            }
        }
        #if DEBUG
        .sheet(item: $screenshotCatalogItem, onDismiss: resumePendingReminderRoute) { item in ServiceAccountsView(move: move, item: item) }
        .sheet(isPresented: $screenshotLibrary, onDismiss: resumePendingReminderRoute) { MoveLibraryView() }
        #endif
        .sheet(item: $allTasksSheetContext, onDismiss: resyncAfterDashboardSheet) { context in
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
        .sheet(isPresented: $showingReminders, onDismiss: presentPendingNotificationTaskIfNeeded) {
            NavigationStack {
                ReminderControlsView(move: move)
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingReminders = false }
                    } }
            }
        }
        .sheet(isPresented: $showingEditMove, onDismiss: resyncAfterDashboardSheet) {
            EditMoveView(move: move)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingAddMoreServices, onDismiss: resyncAfterDashboardSheet) {
            AddMoreServicesView(move: move, area: areaMarketComparison)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $notificationActionTask, onDismiss: resumePendingReminderRoute) { task in
            TaskActionSheet(
                task: task,
                onAlreadyDone: {
                    completeTask(task)
                    notificationActionTask = nil
                },
                onUpdateNow: {
                    if let url = task.actionURL {
                        UIApplication.shared.open(url)
                    }
                    notificationActionTask = nil
                },
                onLater: { notificationActionTask = nil },
                onNotApplicable: {
                    removeTaskNotApplicable(task)
                    notificationActionTask = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var dashboardOverlays: some View {
        dashboardSheets
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
        .overlay {
            // "Not Applicable" undo toast — same grace-period pattern as completion above,
            // so a mis-tap doesn't permanently lose a task the way it silently did before.
            VStack {
                Spacer()
                if removeUndoVisible {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(Theme.priorityCritical)
                        Text("Removed from your list")
                            .themeText(14, weight: .medium)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button("Undo") { undoRemoval() }
                            .themeText(14, weight: .bold)
                            .foregroundColor(Theme.accentPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.priorityCritical.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: removeUndoVisible)
        }
        .overlay {
            // Whole-move finale — the highest-emotion moment in the app previously did
            // nothing with itself (a disconnected `celebrationTask` var, a static "All
            // Caught Up." label). Fires once per move via Move.completionCelebratedAt.
            if showingCompletionCelebration {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .onTapGesture { withAnimation { showingCompletionCelebration = false } }
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.accentSuccess)
                        Text("Every task is done.")
                            .themeSerif(26, weight: .bold)
                            .foregroundColor(Theme.textPrimary)
                        Text("Everything on your checklist is done. You can still review categories for anything you may have missed.")
                            .themeText(14, weight: .regular)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Button {
                            withAnimation { showingCompletionCelebration = false }
                        } label: {
                            Text("Nice")
                                .themeText(15, weight: .bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 36)
                                .padding(.vertical, 12)
                                .background(Theme.accentSuccess, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(32)
                    .background(Theme.backgroundCard, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 32)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                .transition(.opacity)
            }
        }
    }

    var body: some View {
        dashboardOverlays
        .onChange(of: move.allTasksCompleted) { _, allDone in
            guard allDone, move.completionCelebratedAt == nil else { return }
            move.completionCelebratedAt = Date()
            guard modelContext.saveOrLog() else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showingCompletionCelebration = true
            }
            // Right at the peak positive moment, per Apple's own guidance — the OS
            // throttles how often this can actually show, so calling it is always safe.
            requestAppStoreReviewIfAppropriate()
        }
        .task {
            MoveChecklistService.backfillCatalogIDs(for: move)
            guard modelContext.saveOrLog() else { return }
            locationManager.attach(move, context: modelContext)
            locationManager.startForegroundUpdates()
            // Ask for notification permission here, contextually — once the user has reached
            // their dashboard and reminders are actually about to be scheduled — rather than
            // at cold launch before onboarding, where there's no reason yet to say yes.
            // TEMPORARY: skipped during screenshot seeding so the system prompt doesn't
            // cover the dashboard in captures. Remove alongside the other seed-flag checks.
            #if DEBUG
            if ProcessInfo.processInfo.environment["SEED_SCREENSHOT_DATA"] != "1" {
                reminderService.requestPermissions()
            }
            #else
            reminderService.requestPermissions()
            #endif
            reminderService.reschedule(for: move)
            // Covers a cold launch triggered by tapping a notification — the router's
            // value was set before this view existed, so onChange below wouldn't fire.
            if !presentPendingRemindersIfNeeded() {
                presentPendingNotificationTaskIfNeeded()
            }
            #if DEBUG
            if ProcessInfo.processInfo.environment["SEED_SCREENSHOT_DATA"] == "1" {
                switch ProcessInfo.processInfo.environment["SCREENSHOT_SCREEN"] {
                case "task": notificationActionTask = move.tasks.first { $0.catalogItemID == "wine_club" }
                case "reminders": showingReminders = true
                case "accounts": screenshotCatalogItem = ItemCatalog.byID["wine_club"]
                case "settings": showingEditMove = true
                case "services": showingAddMoreServices = true
                case "library": screenshotLibrary = true
                default: break
                }
            }
            #endif
        }
        .task(id: "\(move.originZip ?? "")|\(move.destinationZip)|\(move.areaInsightsEnabled == true)|\(areaRefreshID)") {
            await loadAreaMarketComparison(refresh: areaRefreshID > 0)
        }
        .onChange(of: ReminderPolicy.revision(for: move)) { _, _ in
            resyncNotificationsAndGeofences()
        }
        .onChange(of: notificationRouter.pendingTaskID) { _, _ in
            presentPendingNotificationTaskIfNeeded()
        }
        .onChange(of: notificationRouter.pendingRemindersMoveID) { _, _ in
            presentPendingRemindersIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Stop continuous GPS the moment the app leaves the foreground — geofence
            // entries still fire via region monitoring while backgrounded/suspended.
            if newPhase == .active {
                resyncNotificationsAndGeofences()
                reminderService.refreshPermissions()
                locationManager.startForegroundUpdates()
                presentPendingRemindersIfNeeded()
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

        guard ChecklistActions.complete(task, in: modelContext) else { return }
        locationManager.taskStatusDidChange(task)

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
        guard ChecklistActions.reopen(task, in: modelContext) else { return }
        lastCompletedTask = nil
        resyncNotificationsAndGeofences()
    }

    // #1 — real 3-day snooze, not a session-only hide
    private func skipTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        ChecklistActions.perform(in: modelContext, move: move) {
            task.snoozedUntil = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        }
    }

    /// A real deletion, not a status change — the task is gone from move.tasks
    /// and (after the undo grace period below) the SwiftData store, so it can't
    /// resurface as the hero task, in Up Next, or in category progress counts,
    /// all of which re-derive their list from move.tasks live. Confirmed via
    /// ZenHeroCard's confirmationDialog before this ever runs. Local notifications
    /// and geofences are a separate concern — they're OS-level state scheduled
    /// with baked-in content, not re-derived on read — so
    /// resyncNotificationsAndGeofences() below handles those explicitly.
    ///
    /// The actual `modelContext.delete` is deferred until the 4-second undo toast
    /// expires — same shape as completeTask/undoLastCompletion — since a mis-tap
    /// here was previously unrecoverable while a mis-tapped completion wasn't.
    private func removeTaskNotApplicable(_ task: ChecklistTask) {
        removeUndoTimer?.invalidate()
        if let previous = lastRemovedTask { modelContext.delete(previous) }
        lastRemovedResponse = MoveChecklistService.catalogID(for: task).flatMap { move.serviceResponses[$0] }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard ChecklistActions.perform(in: modelContext, move: move, mutation: {
            MoveChecklistService.recordDismissal(task, for: move)
            move.tasks.removeAll { $0.id == task.id }
        }) else { return }

        lastRemovedTask = task
        withAnimation(.spring(response: 0.4)) { removeUndoVisible = true }
        removeUndoTimer?.invalidate()
        removeUndoTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { removeUndoVisible = false }
            if let pending = lastRemovedTask {
                modelContext.delete(pending)
                modelContext.saveOrLog()
            }
            lastRemovedTask = nil
        }
    }

    private func undoRemoval() {
        guard let task = lastRemovedTask else { return }
        removeUndoTimer?.invalidate()
        withAnimation(.spring(response: 0.4)) { removeUndoVisible = false }
        guard ChecklistActions.perform(in: modelContext, move: move, mutation: {
            move.tasks.append(task)
            if let id = MoveChecklistService.catalogID(for: task) {
                var responses = move.serviceResponses
                responses[id] = lastRemovedResponse
                move.serviceResponses = responses
            }
        }) else { return }
        lastRemovedTask = nil
        lastRemovedResponse = nil
    }

    private func resyncNotificationsAndGeofences() {
        let active = move.phase == .active ? move : nil
        reminderService.reschedule(for: active)
        locationManager.attach(active, context: modelContext)
    }

    private func requestAppStoreReviewIfAppropriate() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// Consumes a task ID dropped by NotificationRouter (from a tapped notification)
    /// and presents the same TaskActionSheet used for in-dashboard taps.
    private func presentPendingNotificationTaskIfNeeded() {
        guard !showingReminders else { return }
        guard let taskID = notificationRouter.pendingTaskID else { return }
        notificationRouter.pendingTaskID = nil
        notificationActionTask = move.tasks.first(where: { $0.id == taskID })
    }

    /// Only the matching active move may handle a renewal notification. Reviewing
    /// an expired window never opts in or activates a saved move.
    @discardableResult
    private func presentPendingRemindersIfNeeded() -> Bool {
        guard notificationRouter.pendingRemindersMoveID == move.id else { return false }
        guard ReminderPolicy.shouldOfferConsentRenewal(for: move) else {
            notificationRouter.pendingRemindersMoveID = nil
            return false
        }
        // Leave the route queued until the current sheet's dismissal completes.
        guard !showingMailComposer, allTasksSheetContext == nil, !showingEditMove,
              !showingAddMoreServices, notificationActionTask == nil else { return true }
        #if DEBUG
        guard screenshotCatalogItem == nil, !screenshotLibrary else { return true }
        #endif
        notificationRouter.pendingRemindersMoveID = nil
        showingReminders = true
        return true
    }

    private func resumePendingReminderRoute() {
        presentPendingRemindersIfNeeded()
    }

    private func resyncAfterDashboardSheet() {
        resyncNotificationsAndGeofences()
        resumePendingReminderRoute()
    }

    private func triggerAgenticAction(for task: ChecklistTask) {
        // Only open mail composer if the device can send mail
        guard MFMailComposeViewController.canSendMail() else {
            // Fallback: open the task's deep link directly if available
            if let url = task.actionURL {
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
        if ChecklistActions.perform(in: modelContext, move: move, mutation: {
            task.snoozedUntil = Date().addingTimeInterval(86400)
        }) { locationManager.activeContextualTask = nil }
    }

    private func muteContextualTask(_ task: ChecklistTask) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        if ChecklistActions.perform(in: modelContext, move: move, mutation: {
            task.isMuted = true
        }) { locationManager.activeContextualTask = nil }
    }
}
