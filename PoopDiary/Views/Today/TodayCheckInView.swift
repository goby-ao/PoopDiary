import SwiftData
import SwiftUI

struct TodayCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PoopRecord.date, order: .reverse) private var records: [PoopRecord]
    @State private var viewModel = TodayCheckInViewModel()
    @State private var statsViewModel = StatsViewModel()
    @State private var showingFeedbackSettings = false
    @State private var currentDayKey = Calendar.poopDiary.dayKey(for: .now)
    @State private var midnightRefreshTask: Task<Void, Never>?
    @State private var activeFlush: FlushChoreographyRequest?
    @State private var activeCleanRitual: CleanRitualRequest?
    @State private var pendingStompGameSession: PoopStompGameSession?
    @State private var activeStompGameSession: PoopStompGameSession?
    @State private var holdProgress: CGFloat = 0
    @State private var cleanRitualPresentationTask: Task<Void, Never>?
    @State private var pendingProfileSwitch: ChildProfile?
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = "便便小超人"
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID
    @AppStorage(AppPreferenceKey.profilesJSON) private var profilesJSON = ""

    private var profiles: [ChildProfile] {
        ProfileStore.profiles(from: profilesJSON)
    }

    private var activeProfile: ChildProfile? {
        ProfileStore.activeProfile(in: profiles, activeProfileID: activeProfileID)
    }

    private var profileRecords: [PoopRecord] {
        records.filter { $0.profileID == activeProfileID }
    }

    private var todayRecord: PoopRecord? {
        profileRecords.first { $0.dayKey == currentDayKey }
    }

    var body: some View {
        GeometryReader { proxy in
            content(proxy: proxy)
        }
        .background(background)
        .navigationTitle("便便超人")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingFeedbackSettings = true
                    InteractionFeedback.play(sound: .tap, haptic: .light)
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("家长设置")
            }
        }
        .sheet(isPresented: $showingFeedbackSettings) {
            FeedbackSettingsView()
        }
        .fullScreenCover(item: $activeStompGameSession, onDismiss: {
            activeStompGameSession = nil
        }) { session in
            PoopStompGameView(session: session) { result in
                PoopStompGameProgressStore.finalize(result, for: session)
            }
        }
        .onAppear {
            syncTodayState()
            scheduleMidnightRefresh()
        }
        .onDisappear {
            midnightRefreshTask?.cancel()
            cleanRitualPresentationTask?.cancel()
        }
        .onChange(of: activeProfileID) { _, _ in
            syncTodayState(preserveDraft: false)
        }
        .onChange(of: currentDayKey) { _, _ in
            syncTodayState(preserveDraft: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            currentDayKey = Calendar.poopDiary.dayKey(for: .now)
            scheduleMidnightRefresh()
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: todayRecord?.id)
        .confirmationDialog(
            "切换孩子？",
            isPresented: Binding(
                get: { pendingProfileSwitch != nil },
                set: { if !$0 { pendingProfileSwitch = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingProfileSwitch {
                Button("切换到\(pendingProfileSwitch.nickname)") {
                    activateProfile(pendingProfileSwitch)
                }
            }
            Button("取消", role: .cancel) {
                pendingProfileSwitch = nil
            }
        } message: {
            Text("当前未完成的打卡选择会清空，已经保存的记录不受影响。")
        }
        .alert("出错啦", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            ZStack {
                if let activeFlush {
                    FlushChoreographyOverlay(request: activeFlush) {
                        let savedRecord = viewModel.confirmSelection(profileID: activeProfileID, in: modelContext, playFeedback: false)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            self.activeFlush = nil
                        }

                        if savedRecord != nil, viewModel.errorMessage == nil {
                            prepareStompGameSession()
                            if activeFlush.didPoop {
                                scheduleCleanRitual(for: activeFlush)
                            } else {
                                presentPendingStompGame()
                            }
                        }
                    }
                    .transition(.opacity)
                    .zIndex(9)
                }

                if let activeCleanRitual {
                    CleanRitualOverlay(request: activeCleanRitual) {
                        let shouldPresentGame = activeCleanRitual.unlocksStompGame
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            self.activeCleanRitual = nil
                        }

                        if shouldPresentGame {
                            presentPendingStompGame()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(11)
                }

                if let achievement = viewModel.unlockedAchievement {
                    AchievementUnlockOverlay(achievement: achievement) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.unlockedAchievement = nil
                        }
                    }
                    .zIndex(10)
                }
            }
        }
    }

    @ViewBuilder
    private func content(proxy: GeometryProxy) -> some View {
        let metrics = TodayLayoutMetrics(proxy: proxy)

        ZStack {
            background

            VStack(spacing: 0) {
                header(record: todayRecord)
                    .frame(height: metrics.headerHeight)

                Spacer(minLength: metrics.gap)

                if let todayRecord {
                    completedContent(record: todayRecord, metrics: metrics)
                        .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                } else {
                    checkInContent(metrics: metrics)
                        .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.96).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, metrics.topPadding)
            .padding(.bottom, metrics.bottomPadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func checkInContent(metrics: TodayLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            MascotStage(
                mood: viewModel.mood,
                bounceTrigger: viewModel.rewardTrigger,
                height: metrics.mascotHeight
            ) {
                viewModel.tapMascot(profileID: activeProfileID, in: modelContext)
            }
            .scaleEffect(1 - holdProgress * 0.035)
            .offset(y: holdProgress * 12)
            .rotationEffect(.degrees(-2.5 * holdProgress))
            .animation(.spring(response: 0.34, dampingFraction: 0.58), value: holdProgress)
            .overlay {
                CelebrationOverlay(effect: viewModel.effect, trigger: viewModel.rewardTrigger)
                    .frame(width: metrics.mascotHeight * 1.35, height: metrics.mascotHeight)
            }
            .frame(height: metrics.mascotHeight)

            Spacer(minLength: metrics.gap)

            HStack(spacing: metrics.buttonGap) {
                CheckInChoiceButton(
                    title: "拉了",
                    emoji: "💩",
                    isSelected: viewModel.didPoop == true,
                    tint: .poopAccent,
                    height: metrics.choiceHeight
                ) {
                    viewModel.preparePoopSelection()
                }

                CheckInChoiceButton(
                    title: "没拉",
                    emoji: "😴",
                    isSelected: viewModel.didPoop == false,
                    tint: .mint,
                    height: metrics.choiceHeight
                ) {
                    viewModel.preselectNoPoop()
                }
            }
            .frame(height: metrics.choiceHeight)

            Spacer(minLength: metrics.gap)

            amountSelector(height: metrics.amountHeight)
                .opacity(viewModel.didPoop == true ? 1 : 0.42)
                .frame(height: metrics.amountHeight)

            Spacer(minLength: metrics.gap)

            checkInHint
                .frame(height: metrics.footerHeight)
        }
    }

    private func completedContent(record: PoopRecord, metrics: TodayLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            TodayResultCard(
                record: record,
                message: resultMessage(for: record),
                mascotHeight: metrics.resultMascotHeight,
                trigger: viewModel.rewardTrigger,
                onReset: resetTodayRecord
            ) {
                viewModel.tapMascot(profileID: activeProfileID, in: modelContext)
            }
            .overlay {
                CelebrationOverlay(effect: record.didPoop ? viewModel.effect : .idle, trigger: viewModel.rewardTrigger)
                    .frame(width: metrics.resultHeroHeight, height: metrics.resultHeroHeight)
            }
            .frame(height: metrics.resultHeroHeight)

            Spacer(minLength: metrics.gap)

            HStack(spacing: metrics.buttonGap) {
                TodayMetricTile(
                    title: "连续打卡",
                    value: "\(statsViewModel.currentStreak(records: profileRecords)) 天",
                    systemImage: "flame.fill",
                    tint: .orange
                )

                TodayMetricTile(
                    title: "本月记录",
                    value: "\(statsViewModel.currentMonthPoopCount(records: profileRecords)) 次",
                    systemImage: "calendar.badge.checkmark",
                    tint: .poopAccent
                )
            }
            .frame(height: metrics.summaryHeight)

            Spacer(minLength: metrics.gap)

            if pendingStompGameSession != nil {
                TodayGameChallengeButton(action: presentPendingStompGame)
                    .frame(height: metrics.miniDataHeight)
            } else {
                TodayMiniDataCard(
                    weekCount: currentWeekCheckInCount(),
                    distribution: statsViewModel.amountDistribution(records: profileRecords, days: 7)
                )
                .frame(height: metrics.miniDataHeight)
            }

            Spacer(minLength: metrics.gap)
        }
    }

    private func header(record: PoopRecord?) -> some View {
        VStack(spacing: 5) {
            Text(DateText.todayTitle())
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                profileSwitcher

                Text(record == nil ? "今天拉粑粑了吗？" : "今日小星星已点亮")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileSwitcher: some View {
        Menu {
            ForEach(profiles) { profile in
                Button {
                    requestProfileSwitch(profile)
                } label: {
                    Label(
                        profile.nickname,
                        systemImage: profile.id == activeProfile?.id ? "checkmark.circle.fill" : "person.crop.circle"
                    )
                }
                .disabled(profile.id == activeProfile?.id)
            }

            if !profiles.isEmpty {
                Divider()
            }

            Button {
                showingFeedbackSettings = true
                InteractionFeedback.play(sound: .tap, haptic: .light)
            } label: {
                Label("管理孩子档案…", systemImage: "person.2.fill")
            }
        } label: {
            HStack(spacing: 8) {
                ProfileIdentityMark(profileID: activeProfile?.id ?? activeProfileID, nickname: nickname)
                    .frame(width: 28, height: 28)

                Text(nickname)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: 72, alignment: .leading)
                    .contentTransition(.opacity)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.poopAccent)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 7)
            .padding(.trailing, 11)
            .frame(height: 42)
            .background(Color.poopCream.opacity(0.96), in: Capsule())
            .shadow(color: Color.poopAccent.opacity(0.12), radius: 8, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(ProfileSwitcherButtonStyle())
        .accessibilityLabel("当前孩子 \(nickname)，点按切换")
        .animation(.easeOut(duration: 0.18), value: activeProfileID)
    }

    private func amountSelector(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.didPoop == true ? "今天的量" : "选择「拉了」后选量")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 8) {
                ForEach(PoopAmount.checkInChoices) { amount in
                    AmountButton(
                        amount: amount,
                        isSelected: viewModel.didPoop == true && viewModel.amount == amount,
                        height: max(46, height - 36)
                    ) {
                        // 量按钮自己兜底：即使用户刚点完「拉了」立刻点量，
                        // 也不会被外层 disabled 状态吞掉点击。
                        if viewModel.didPoop != true {
                            viewModel.preparePoopSelection()
                        }
                        viewModel.selectAmount(amount)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var checkInHint: some View {
        VStack(spacing: 6) {
            HoldFlushConfirmButton(
                isReady: viewModel.hasPreselection,
                title: confirmTitle,
                onNotReady: {
                    viewModel.errorMessage = "请先选今天的量"
                    Haptics.play(.soft)
                },
                onProgressChange: { progress in
                    holdProgress = progress
                },
                onComplete: beginFlushChoreography
            )

            Button {
                viewModel.resetSelection()
            } label: {
                Text("选错了？重选")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.didPoop == nil ? 0 : 1)
            .disabled(viewModel.didPoop == nil)
        }
    }

    private var confirmTitle: String {
        guard let didPoop = viewModel.didPoop else {
            return "长按冲水确认 🌀"
        }

        if didPoop {
            return viewModel.amount == .none ? "先选量再冲水 🌀" : "长按冲水确认 🌀"
        }

        return "长按温柔确认 🌀"
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.poopPrimary.opacity(0.18),
                Color(uiColor: .systemBackground),
                Color.poopCream.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var nickname: String {
        ProfileStore.cleanNickname(activeProfile?.nickname ?? childNickname)
    }

    private func requestProfileSwitch(_ profile: ChildProfile) {
        guard profile.id != activeProfile?.id else { return }

        if todayRecord == nil, viewModel.hasPreselection {
            pendingProfileSwitch = profile
            Haptics.play(.soft)
        } else {
            activateProfile(profile)
        }
    }

    private func activateProfile(_ profile: ChildProfile) {
        cleanRitualPresentationTask?.cancel()
        activeFlush = nil
        activeCleanRitual = nil
        pendingStompGameSession = nil
        activeStompGameSession = nil
        pendingProfileSwitch = nil
        holdProgress = 0
        viewModel.unlockedAchievement = nil

        childNickname = ProfileStore.cleanNickname(profile.nickname)
        activeProfileID = profile.id
        InteractionFeedback.play(sound: .tap, haptic: .light)
    }

    private func resultMessage(for record: PoopRecord) -> String {
        guard record.didPoop else {
            return "小肚肚今天休息一下，也很棒"
        }

        switch record.amount {
        case .small:
            return "少量也棒，认真记录最闪亮"
        case .normal:
            return "节奏刚刚好，撒花庆祝"
        case .large:
            return "超厉害，大奖杯亮起来"
        case .none:
            return "今天记录完成啦"
        }
    }

    private func currentWeekCheckInCount() -> Int {
        let calendar = Calendar.poopDiary
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return profileRecords.filter { record in
            record.date >= weekInterval.start && record.date < weekInterval.end
        }.count
    }

    private func syncTodayState(preserveDraft: Bool = true) {
        viewModel.loadToday(profileID: activeProfileID, in: modelContext, preserveDraft: preserveDraft)
        prepareStompGameSession()
    }

    private func beginFlushChoreography() {
        guard viewModel.hasPreselection, let didPoop = viewModel.didPoop else {
            viewModel.errorMessage = "请先选今天的量"
            Haptics.play(.soft)
            return
        }

        guard !didPoop || viewModel.amount != .none else {
            viewModel.errorMessage = "请先选今天的量"
            Haptics.play(.soft)
            return
        }

        holdProgress = 0
        activeFlush = FlushChoreographyRequest(
            didPoop: didPoop,
            amount: didPoop ? viewModel.amount : .none
        )
    }

    private func resetTodayRecord() {
        activeFlush = nil
        activeCleanRitual = nil
        pendingStompGameSession = nil
        activeStompGameSession = nil
        cleanRitualPresentationTask?.cancel()
        holdProgress = 0

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            viewModel.resetTodayRecord(profileID: activeProfileID, in: modelContext)
        }
    }

    private func scheduleCleanRitual(for flush: FlushChoreographyRequest) {
        cleanRitualPresentationTask?.cancel()

        let request = CleanRitualRequest(
            amount: flush.amount,
            nickname: nickname,
            unlocksStompGame: pendingStompGameSession != nil
        )
        cleanRitualPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                activeCleanRitual = request
            }
        }
    }

    private func prepareStompGameSession() {
        do {
            pendingStompGameSession = try PoopStompGameGate.makeSessionIfEligible(
                profileID: activeProfileID,
                in: modelContext
            )
        } catch {
            pendingStompGameSession = nil
        }
    }

    private func presentPendingStompGame() {
        guard let session = pendingStompGameSession else { return }

        pendingStompGameSession = nil
        activeStompGameSession = session
    }

    private func scheduleMidnightRefresh() {
        midnightRefreshTask?.cancel()

        let calendar = Calendar.poopDiary
        let now = Date.now
        let todayStart = calendar.startOfDay(for: now)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }

        let delay = max(nextDay.timeIntervalSince(now) + 0.5, 1)
        let delayNanoseconds = UInt64(min(delay, Double(UInt64.max) / 1_000_000_000) * 1_000_000_000)
        midnightRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)

            let nextDayKey = Calendar.poopDiary.dayKey(for: .now)
            if nextDayKey != currentDayKey {
                currentDayKey = nextDayKey
                syncTodayState(preserveDraft: false)
            }

            scheduleMidnightRefresh()
        }
    }
}

private struct TodayLayoutMetrics {
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let gap: CGFloat
    let buttonGap: CGFloat
    let headerHeight: CGFloat
    let mascotHeight: CGFloat
    let choiceHeight: CGFloat
    let amountHeight: CGFloat
    let footerHeight: CGFloat
    let resultHeroHeight: CGFloat
    let resultMascotHeight: CGFloat
    let summaryHeight: CGFloat
    let miniDataHeight: CGFloat

    init(proxy: GeometryProxy) {
        let safeInsets = proxy.safeAreaInsets
        let availableHeight = max(proxy.size.height - safeInsets.top - safeInsets.bottom, 430)
        let compact = proxy.size.width <= 375 || availableHeight < 560

        horizontalPadding = compact ? 14 : 20
        topPadding = max(6, safeInsets.top * 0.18)
        bottomPadding = max(8, safeInsets.bottom * 0.18)
        gap = min(max(availableHeight * 0.018, 6), 14)
        buttonGap = compact ? 10 : 14
        headerHeight = min(max(availableHeight * 0.13, 62), compact ? 78 : 92)
        mascotHeight = min(max(availableHeight * 0.28, 132), compact ? 168 : 214)
        choiceHeight = min(max(availableHeight * 0.14, 68), compact ? 88 : 112)
        amountHeight = min(max(availableHeight * 0.14, 74), compact ? 94 : 116)
        footerHeight = min(max(availableHeight * 0.12, 68), compact ? 82 : 96)
        resultHeroHeight = min(max(availableHeight * 0.305, 146), compact ? 178 : 218)
        resultMascotHeight = min(resultHeroHeight * 0.82, compact ? 138 : 174)
        summaryHeight = min(max(availableHeight * 0.14, 72), compact ? 90 : 108)
        miniDataHeight = min(max(availableHeight * 0.195, 108), compact ? 128 : 156)
    }
}

private struct ProfileIdentityMark: View {
    let profileID: String
    let nickname: String

    private var initial: String {
        let cleaned = ProfileStore.cleanNickname(nickname)
        return String(cleaned.prefix(1))
    }

    private var tint: Color {
        let palette: [Color] = [.poopAccent, .orange, .pink, .cyan, .mint]
        let index = profileID.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult * 31 + Int(scalar.value)) % palette.count
        }
        return palette[index]
    }

    var body: some View {
        Circle()
            .fill(tint.gradient)
            .overlay {
                Text(initial)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.82), lineWidth: 1.2)
            }
            .shadow(color: tint.opacity(0.22), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}

private struct ProfileSwitcherButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MascotStage: View {
    let mood: MascotMood
    let bounceTrigger: UUID
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        let scale = min(max(height / 220, 0.58), 1.08)

        PoopMascotView(mood: mood, bounceTrigger: bounceTrigger, onTap: onTap)
            .scaleEffect(scale)
            .frame(width: 220 * scale, height: 220 * scale)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
    }
}

private struct CheckInChoiceButton: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let tint: Color
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        let cornerRadius = min(height * 0.28, 26)

        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: min(height * 0.34, 34)))

                Text(title)
                    .font(.system(size: min(height * 0.22, 22), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.92) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.75) : tint.opacity(0.28), lineWidth: 2)
            }
            .shadow(color: isSelected ? tint.opacity(0.24) : .black.opacity(0.04), radius: 12, y: 7)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct AmountButton: View {
    let amount: PoopAmount
    let isSelected: Bool
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        let cornerRadius = min(height * 0.26, 18)

        VStack(spacing: 3) {
            Text(amount.emoji)
                .font(.system(size: min(height * 0.34, 25)))

            Text(amount.title)
                .font(.system(size: min(height * 0.22, 15), weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(isSelected ? Color.poopAccent.opacity(0.9) : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .foregroundStyle(isSelected ? .white : .primary)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isSelected ? .white.opacity(0.75) : Color.poopAccent.opacity(0.18), lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture(perform: action)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(amount.title)
    }
}

private struct HoldFlushConfirmButton: View {
    let isReady: Bool
    let title: String
    let onNotReady: () -> Void
    let onProgressChange: (CGFloat) -> Void
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var rejectedCurrentPress = false
    @State private var completedCurrentPress = false
    @State private var progressTask: Task<Void, Never>?
    @State private var holdFeedbackTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))

            GeometryReader { proxy in
                Capsule()
                    .fill(Color.poopPrimary.gradient)
                    .frame(width: proxy.size.width * progress)
                    .animation(.timingCurve(0.33, 0, 0.2, 1, duration: 0.06), value: progress)
            }

            HStack(spacing: 8) {
                Image(systemName: isPressing ? "water.waves" : "hand.tap.fill")
                    .font(.system(size: 17, weight: .black))

                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.black))
                    .opacity(isPressing ? 1 : 0.55)
            }
            .padding(.horizontal, 18)
            .foregroundStyle(progress > 0.52 ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    startHoldingIfNeeded()
                }
                .onEnded { _ in
                    cancelIfNeeded()
                }
        )
        .shadow(color: Color.poopAccent.opacity(isPressing ? 0.22 : 0.08), radius: 12, y: 7)
        .onDisappear {
            progressTask?.cancel()
            stopHoldFeedback()
            onProgressChange(0)
        }
    }

    private func startHoldingIfNeeded() {
        guard !isPressing, !completedCurrentPress else { return }

        guard isReady else {
            if !rejectedCurrentPress {
                rejectedCurrentPress = true
                onNotReady()
            }
            return
        }

        isPressing = true
        progress = 0
        onProgressChange(0)
        progressTask?.cancel()
        startHoldFeedback()

        progressTask = Task { @MainActor in
            let steps = 28

            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(58))
                guard !Task.isCancelled else { return }

                let nextProgress = easeInOutCubic(CGFloat(step) / CGFloat(steps))
                progress = nextProgress
                onProgressChange(nextProgress)

                // 蓄力过程中给渐强的触觉节奏，暗示冲水越来越近。
                if step == 7 || step == 14 || step == 21 {
                    Haptics.play(.light)
                } else if step == 26 {
                    Haptics.play(.medium)
                }
            }

            isPressing = false
            completedCurrentPress = true
            progress = 1
            onProgressChange(1)
            stopHoldFeedback()
            Haptics.success()
            onComplete()
            try? await Task.sleep(for: .milliseconds(180))
            progress = 0
            onProgressChange(0)
        }
    }

    private func cancelIfNeeded() {
        if completedCurrentPress {
            completedCurrentPress = false
            return
        }

        rejectedCurrentPress = false
        guard isPressing else { return }

        progressTask?.cancel()
        stopHoldFeedback()
        isPressing = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
            progress = 0
            onProgressChange(0)
        }
        Haptics.play(.soft)
    }

    private func startHoldFeedback() {
        holdFeedbackTask?.cancel()
        SoundManager.shared.stopFlushGurgle()

        let hasContinuousGurgle = SoundManager.shared.startFlushGurgle()
        let hasContinuousRumble = Haptics.startFlushRumble()
        holdFeedbackTask = Task { @MainActor in
            var pulse = 0
            Haptics.play(.soft)

            while !Task.isCancelled {
                if !hasContinuousGurgle && pulse.isMultiple(of: 2) {
                    SoundManager.shared.playFlushGurglePulse(pulse)
                }

                if !hasContinuousRumble {
                    if pulse.isMultiple(of: 3) {
                        Haptics.play(.heavy)
                    } else {
                        Haptics.play(.medium)
                    }
                } else if pulse.isMultiple(of: 5) {
                    Haptics.play(.light)
                }

                pulse += 1
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func stopHoldFeedback() {
        holdFeedbackTask?.cancel()
        holdFeedbackTask = nil
        SoundManager.shared.stopFlushGurgle()
        Haptics.stopFlushRumble()
    }
}

private struct FlushChoreographyRequest: Identifiable, Equatable {
    let id = UUID()
    let didPoop: Bool
    let amount: PoopAmount

    var symbol: String {
        didPoop ? "💩" : "😴"
    }

    var intensity: CGFloat {
        guard didPoop else { return 0.72 }

        switch amount {
        case .none:
            return 0.78
        case .small:
            return 0.86
        case .normal:
            return 1
        case .large:
            return 1.22
        }
    }

    var dropletCount: Int {
        guard didPoop else { return 3 }

        switch amount {
        case .none:
            return 3
        case .small:
            return 4
        case .normal:
            return 6
        case .large:
            return 8
        }
    }
}

private struct FlushChoreographyOverlay: View {
    let request: FlushChoreographyRequest
    let onFinished: () -> Void

    private let mainDuration: TimeInterval = 1.58
    private let aftermathDuration: TimeInterval = 0.50

    @State private var startDate = Date.now
    @State private var finishTask: Task<Void, Never>?
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let progress = clamp(CGFloat(elapsed / mainDuration), lower: 0, upper: 1)
            let aftermathProgress = clamp(CGFloat((elapsed - mainDuration) / aftermathDuration), lower: 0, upper: 1)

            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.10 + 0.12 * easeInOutCubic(progress)))
                    .ignoresSafeArea()

                FlushStageView(
                    request: request,
                    progress: progress,
                    aftermathProgress: aftermathProgress
                )
            }
        }
        .allowsHitTesting(true)
        .onAppear {
            startDate = .now
            scheduleFinish()
            scheduleFeedback()
            SoundManager.shared.play(.flush)
        }
        .onDisappear {
            finishTask?.cancel()
            feedbackTask?.cancel()
        }
    }

    private func scheduleFinish() {
        finishTask?.cancel()

        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(mainDuration + aftermathDuration + 0.04))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    private func scheduleFeedback() {
        feedbackTask?.cancel()

        feedbackTask = Task { @MainActor in
            // 触觉按阶段对齐：聚集轻、卷入渐强、吞没成功。
            Haptics.play(.light)
            try? await Task.sleep(for: .seconds(mainDuration * 0.30))
            guard !Task.isCancelled else { return }
            Haptics.play(.light)

            try? await Task.sleep(for: .seconds(mainDuration * 0.22))
            guard !Task.isCancelled else { return }
            Haptics.play(request.intensity > 1.05 ? .medium : .light)

            try? await Task.sleep(for: .seconds(mainDuration * 0.23))
            guard !Task.isCancelled else { return }
            Haptics.play(request.intensity > 1.12 ? .heavy : .medium)

            try? await Task.sleep(for: .seconds(mainDuration * 0.22))
            guard !Task.isCancelled else { return }
            Haptics.success()
        }
    }
}

private struct FlushStageView: View {
    let request: FlushChoreographyRequest
    let progress: CGFloat
    let aftermathProgress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let base = min(proxy.size.width * 0.78, proxy.size.height * 0.56, 330)
            let gather = easeInOutCubic(phaseProgress(progress, from: 0, to: 0.30))
            let entrain = easeInOutCubic(phaseProgress(progress, from: 0.30, to: 0.75))
            let swallow = easeInCubic(phaseProgress(progress, from: 0.75, to: 1))
            let aftermath = easeOutCubic(aftermathProgress)
            let centerY = proxy.size.height * 0.48
            let orbitTurns = (1.05 + request.intensity * 0.42) * entrain + (0.72 + request.intensity * 0.38) * swallow
            let orbitAngle = CGFloat.pi * 2 * orbitTurns - gather * 0.18
            let orbitRadius = base * (0.03 * gather + 0.19 * entrain * (1 - swallow * 0.42))
            let suctionY = base * (0.035 * gather + 0.29 * entrain + 0.24 * swallow)
            let poopScale = max(0.04, 1 - gather * 0.07 - entrain * 0.47 - swallow * 0.45)
            let poopOpacity = max(0, 1 - swallow * 1.35)
            let wobble = sin(Double(progress) * Double.pi * 7) * Double(1 - entrain) * 3.4

            ZStack {
                FlushSwirl(
                    progress: progress,
                    gather: gather,
                    entrain: entrain,
                    swallow: swallow,
                    intensity: request.intensity
                )
                .frame(width: base, height: base)
                .offset(y: base * 0.16)

                if aftermathProgress > 0 {
                    WaterRipple(progress: aftermath, intensity: request.intensity)
                        .frame(width: base * 1.1, height: base * 1.1)
                        .offset(y: base * 0.16)
                }

                PoopShadow(progress: progress, gather: gather, entrain: entrain, swallow: swallow)
                    .frame(width: base * 0.32, height: base * 0.075)
                    .offset(y: base * 0.31 + suctionY * 0.24)

                Text(request.symbol)
                    .font(.system(size: min(base * 0.29, 92)))
                    .scaleEffect(poopScale)
                    .rotationEffect(.degrees(Double(orbitTurns * 430 * request.intensity + swallow * 300)))
                    .offset(
                        x: cos(orbitAngle) * orbitRadius + CGFloat(wobble),
                        y: suctionY + sin(orbitAngle) * orbitRadius * 0.46
                    )
                    .opacity(poopOpacity)
                    .shadow(color: .black.opacity(0.16 * (1 - swallow)), radius: 14, y: 10)

                ForEach(0..<request.dropletCount, id: \.self) { index in
                    AftermathDrop(
                        index: index,
                        base: base,
                        progress: aftermathProgress,
                        intensity: request.intensity,
                        includesTinyPoop: request.didPoop
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .position(x: proxy.size.width / 2, y: centerY)
        }
    }
}

private struct FlushSwirl: View {
    let progress: CGFloat
    let gather: CGFloat
    let entrain: CGFloat
    let swallow: CGFloat
    let intensity: CGFloat

    var body: some View {
        let power = clamp(gather * 0.34 + entrain * 0.58 + swallow * 0.98, lower: 0, upper: 1)
        let shrink = phaseProgress(progress, from: 0.86, to: 1)
        let opacity = clamp(gather * 0.9 + entrain + swallow, lower: 0, upper: 1) * (1 - shrink * 0.48)
        let rotation = 48 * gather + 460 * entrain * intensity + 760 * swallow * intensity
        let scale = 0.66 + gather * 0.13 + entrain * 0.22 - shrink * 0.18

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.55 * power),
                            .poopPrimary.opacity(0.22 * power),
                            .cyan.opacity(0.08 * power),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 150
                    )
                )
                .scaleEffect(0.72 + power * 0.3)

            Circle()
                .trim(from: 0.04, to: 0.92)
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.18),
                            .cyan.opacity(0.72),
                            .poopPrimary.opacity(0.92),
                            .poopAccent.opacity(0.82),
                            .white.opacity(0.12)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18 + 8 * power, lineCap: .round)
                )
                .rotationEffect(.degrees(Double(rotation)))

            Circle()
                .trim(from: 0.18, to: 0.76)
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.7),
                            .poopPrimary.opacity(0.8),
                            .clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8 + 4 * power, lineCap: .round)
                )
                .scaleEffect(0.64 + power * 0.14)
                .rotationEffect(.degrees(Double(-rotation * 1.28)))

            Circle()
                .stroke(.white.opacity(0.2 * power), lineWidth: 2)
                .scaleEffect(0.28 + power * 0.18)
                .blur(radius: 0.5)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

private struct PoopShadow: View {
    let progress: CGFloat
    let gather: CGFloat
    let entrain: CGFloat
    let swallow: CGFloat

    var body: some View {
        let shadowScale = max(0.08, 1 - gather * 0.16 - entrain * 0.52 - swallow * 0.34)
        let opacity = max(0, 0.24 - entrain * 0.11 - swallow * 0.18)

        Capsule()
            .fill(.black.opacity(opacity))
            .scaleEffect(x: shadowScale, y: max(0.18, shadowScale * 0.72), anchor: .center)
            .blur(radius: 6 + progress * 2)
    }
}

private struct WaterRipple: View {
    let progress: CGFloat
    let intensity: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.poopPrimary.opacity((1 - progress) * 0.44), lineWidth: max(1.2, 7 * (1 - progress)))
                .scaleEffect(0.16 + progress * (0.72 + intensity * 0.08))

            Circle()
                .stroke(.white.opacity((1 - progress) * 0.28), lineWidth: 2.5)
                .scaleEffect(0.08 + progress * (0.52 + intensity * 0.06))
        }
        .opacity(progress > 0 ? 1 : 0)
    }
}

private struct AftermathDrop: View {
    let index: Int
    let base: CGFloat
    let progress: CGFloat
    let intensity: CGFloat
    let includesTinyPoop: Bool

    var body: some View {
        let delay = min(0.62, CGFloat(index) * 0.075 + CGFloat(index % 3) * 0.022)
        let local = clamp((progress - delay) / max(0.12, 1 - delay), lower: 0, upper: 1)
        let fall = easeInCubic(local)
        let fade = min(local * 3.2, max(0, (1 - local) * 2.4))
        let side = CGFloat((index % 5) - 2) * base * 0.07
        let drift = side + sin(Double(local) * Double.pi) * CGFloat(index.isMultiple(of: 2) ? 16 : -14) * intensity
        let startY = -base * (0.13 + CGFloat(index % 3) * 0.035)
        let endY = base * (0.27 + CGFloat(index % 4) * 0.04)
        let symbol = includesTinyPoop && index.isMultiple(of: 5) ? "💩" : "💧"

        Text(symbol)
            .font(.system(size: symbol == "💩" ? base * 0.105 : base * 0.082))
            .rotationEffect(.degrees(Double(index * 21) + Double(local * 95) * (index.isMultiple(of: 2) ? 1 : -1)))
            .scaleEffect((symbol == "💩" ? 0.72 : 1) * (0.78 + easeOutCubic(local) * 0.22))
            .offset(x: drift, y: startY + (endY - startY) * fall)
            .opacity(fade)
    }
}

private func phaseProgress(_ progress: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
    clamp((progress - start) / (end - start), lower: 0, upper: 1)
}

private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}

private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
    let t = clamp(value, lower: 0, upper: 1)

    if t < 0.5 {
        return 4 * t * t * t
    }

    let tail = -2 * t + 2
    return 1 - tail * tail * tail / 2
}

private func easeOutCubic(_ value: CGFloat) -> CGFloat {
    let t = clamp(value, lower: 0, upper: 1)
    let tail = 1 - t
    return 1 - tail * tail * tail
}

private func easeInCubic(_ value: CGFloat) -> CGFloat {
    let t = clamp(value, lower: 0, upper: 1)
    return t * t * t
}

private struct TodayResultCard: View {
    let record: PoopRecord
    let message: String
    let mascotHeight: CGFloat
    let trigger: UUID
    let onReset: () -> Void
    let onMascotTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                MascotStage(
                    mood: record.didPoop ? .happy : .sleepy,
                    bounceTrigger: trigger,
                    height: mascotHeight,
                    onTap: onMascotTap
                )
                .frame(width: mascotHeight * 1.04)

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.didPoop ? "\(record.amount.emoji) \(record.amount.title)" : "😴 没拉")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(message)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Label("今日结果", systemImage: "star.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.trailing, 28)

            Button(action: onReset) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.secondary.opacity(0.74))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.42), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .accessibilityLabel("重置今天记录")
            .accessibilityHint("清除今天的记录并重新选择")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.yellow.opacity(0.22), .poopPrimary.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
}

private struct TodayMetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct TodayMiniDataCard: View {
    let weekCount: Int
    let distribution: [AmountDistributionSlice]

    private var total: Int {
        distribution.map(\.count).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("本周趣味数据", systemImage: "chart.bar.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer()

                Text("本周 \(weekCount) 天")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.poopAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.poopAccent.opacity(0.12), in: Capsule())
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                ForEach(distribution) { slice in
                    MiniAmountBar(slice: slice, total: max(total, 1))
                }
            }

            Text(total == 0 ? "明天继续观察" : "近 7 天 · 少量 / 正常 / 很多")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct TodayGameChallengeButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            InteractionFeedback.play(sound: .tap, haptic: .medium)
            action()
        } label: {
            HStack(spacing: 15) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("开始今日清扫挑战")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("点击落脚 · 三波挑战 · 每天一次")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 26, weight: .black))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(Color.poopAccent.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.poopAccent.opacity(0.24), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("开始今日清扫挑战，点击落脚，三波挑战，每天一次")
    }
}

private struct MiniAmountBar: View {
    let slice: AmountDistributionSlice
    let total: Int

    private var ratio: CGFloat {
        CGFloat(slice.count) / CGFloat(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(slice.amount.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 2)

                Text("\(slice.count)")
                    .font(.system(.subheadline, design: .rounded).weight(.black).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))

                    if slice.count > 0 {
                        Capsule()
                            .fill(color.gradient)
                            .frame(width: max(12, proxy.size.width * ratio))
                    }
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var color: Color {
        switch slice.amount {
        case .small:
            return .poopLightGreen
        case .normal:
            return .poopMediumGreen
        case .large:
            return .poopDeepGreen
        case .none:
            return .gray.opacity(0.24)
        }
    }
}

#Preview("SE 未打卡") {
    NavigationStack {
        TodayCheckInView()
    }
    .modelContainer(SampleData.emptyPreviewContainer())
    .frame(width: 375, height: 667)
}

#Preview("14 Pro 已打卡") {
    NavigationStack {
        TodayCheckInView()
    }
    .modelContainer(SampleData.previewContainer())
    .frame(width: 393, height: 852)
}

#Preview("16 Pro Max 已打卡") {
    NavigationStack {
        TodayCheckInView()
    }
    .modelContainer(SampleData.previewContainer())
    .frame(width: 440, height: 956)
}
