import SwiftUI

struct PoopStompGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: PoopStompGameSession
    let onFinished: (PoopStompGameResult) -> PoopStompStickerUnlock

    @State private var startDate = Date.now
    @State private var countdownStartedAt = Date.now
    @State private var phase: StompGamePhase = .countdown
    @State private var pausedAt: Date?
    @State private var accumulatedPause: TimeInterval = 0
    @State private var lastSpawnDate = Date.distantPast
    @State private var bootPosition: CGPoint?
    @State private var stageSize: CGSize = .zero
    @State private var poops: [StompTarget] = []
    @State private var bursts: [StompBurst] = []
    @State private var score = 0
    @State private var stompCount = 0
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var lastStompDate = Date.distantPast
    @State private var lastStompAttemptDate = Date.distantPast
    @State private var bootResetTask: Task<Void, Never>?
    @State private var cleanliness = 100
    @State private var escapedCount = 0
    @State private var currentWave: StompGameWave = .warmUp
    @State private var waveAnnouncementUntil = Date.distantPast
    @State private var isFinished = false
    @State private var result: PoopStompGameResult?
    @State private var didRecordResult = false
    @State private var previousHighScore = 0
    @State private var resultReport = ""
    @State private var stickerUnlock: PoopStompStickerUnlock?
    @State private var feverUntil = Date.distantPast
    @State private var feverCount = 0
    @State private var shieldUntil = Date.distantPast
    @State private var powerUpCount = 0
    @State private var mineMistakeCount = 0

    private let tick = Timer.publish(every: 0.14, on: .main, in: .common).autoconnect()
    private let countdownDuration: TimeInterval = 3.0
    private let stompCooldown: TimeInterval = 0.34
    private let stompRadius: CGFloat = 58
    private let waveAnnouncementDuration: TimeInterval = 1.0

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 18.0 : 1.0 / 30.0)) { timeline in
                let date = timeline.date
                let adjustedElapsed = gameElapsed(at: date)
                let remaining = max(session.duration - adjustedElapsed, 0)
                let countdownValue = countdownNumber(at: date)
                let feverActive = isFeverActive(at: date)
                let shieldRemaining = max(shieldUntil.timeIntervalSince(date), 0)
                let isAnnouncingWave = waveAnnouncementUntil > date

                ZStack {
                    StompFieldBackground()

                    if feverActive {
                        StompFeverOverlay(date: date, reduceMotion: reduceMotion)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }

                    StompTrackMarks(date: date, reduceMotion: reduceMotion)
                        .allowsHitTesting(false)

                    ForEach(poops) { target in
                        StompTargetView(target: target, date: date, reduceMotion: reduceMotion)
                            .allowsHitTesting(false)
                    }

                    ForEach(bursts) { burst in
                        StompBurstView(burst: burst, date: date, reduceMotion: reduceMotion)
                            .allowsHitTesting(false)
                    }

                    if let bootPosition {
                        StompLandingView(radius: stompRadius, reduceMotion: reduceMotion)
                            .position(bootPosition)
                            .allowsHitTesting(false)
                    }

                    StompGameHUD(
                        remaining: remaining,
                        score: score,
                        combo: combo,
                        cleanliness: cleanliness,
                        wave: currentWave,
                        isPaused: phase == .paused,
                        isFeverActive: feverActive,
                        shieldRemaining: shieldRemaining,
                        onPauseToggle: {
                            togglePause(at: .now)
                        }
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(10)

                    if phase == .countdown {
                        StompCountdownOverlay(value: countdownValue, reduceMotion: reduceMotion)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(12)
                    }

                    if phase == .playing, isAnnouncingWave {
                        StompWaveAnnouncementOverlay(wave: currentWave, reduceMotion: reduceMotion)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(13)
                    }

                    if phase == .paused {
                        StompPauseOverlay {
                            resumeGame(at: .now)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(14)
                    }

                    if let result {
                        StompResultOverlay(
                            result: result,
                            previousHighScore: previousHighScore,
                            report: resultReport,
                            stickerUnlock: stickerUnlock
                        ) {
                            InteractionFeedback.play(sound: .tap, haptic: .light)
                            dismiss()
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(20)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            attemptStomp(at: value.location, date: .now)
                        }
                )
                .onAppear {
                    stageSize = proxy.size
                    startGameIfNeeded(size: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    stageSize = newSize
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(tick) { date in
            updateGame(at: date)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            bootResetTask?.cancel()
            SoundManager.shared.stopPoopStompMusic()
        }
        .interactiveDismissDisabled(phase != .finished)
    }

    private func startGameIfNeeded(size: CGSize) {
        guard poops.isEmpty, score == 0, !isFinished, phase == .countdown else { return }

        let now = Date.now
        countdownStartedAt = now
        startDate = now
        lastSpawnDate = .distantPast
        stageSize = size
        previousHighScore = PoopStompGameProgressStore.highScore(profileID: session.profileID)
        resultReport = ""
        stickerUnlock = nil
        didRecordResult = false
        cleanliness = 100
        escapedCount = 0
        currentWave = .warmUp
        waveAnnouncementUntil = .distantPast
        lastStompAttemptDate = .distantPast
        InteractionFeedback.play(sound: .achievement, haptic: .success)
    }

    private func beginPlaying(at date: Date) {
        guard phase == .countdown else { return }

        phase = .playing
        startDate = date
        accumulatedPause = 0
        pausedAt = nil
        lastSpawnDate = .distantPast
        for _ in 0..<4 {
            spawnTarget(at: date)
        }
        SoundManager.shared.startPoopStompMusic()
        Haptics.play(.medium)
    }

    private func updateGame(at date: Date) {
        guard !isFinished else { return }

        if phase == .countdown {
            if date.timeIntervalSince(countdownStartedAt) >= countdownDuration {
                beginPlaying(at: date)
            }
            return
        }

        guard phase == .playing else { return }

        let adjustedElapsed = gameElapsed(at: date)
        if adjustedElapsed >= session.duration {
            finishGame(at: date)
            return
        }

        bursts.removeAll { date.timeIntervalSince($0.createdAt) > 0.92 }

        if let nextWave = currentWave.next, adjustedElapsed >= currentWave.endsAt {
            beginWave(nextWave, at: date)
            return
        }

        guard waveAnnouncementUntil <= date else { return }

        removeExpiredTargets(at: date)

        let feverBoost = isFeverActive(at: date) ? 0.12 : 0
        let spawnInterval = max(0.28, currentWave.spawnInterval - feverBoost)
        let targetLimit = currentWave.targetLimit + (isFeverActive(at: date) ? 2 : 0)

        if poops.count < targetLimit, date.timeIntervalSince(lastSpawnDate) >= spawnInterval {
            spawnTarget(at: date)
            lastSpawnDate = date
        }
    }

    private func spawnTarget(at date: Date, preferredKind: StompTargetKind? = nil) {
        guard stageSize.width > 80, stageSize.height > 180 else { return }

        let kind = preferredKind ?? StompTargetKind.random(
            elapsed: gameElapsed(at: date),
            wave: currentWave,
            isFeverActive: isFeverActive(at: date)
        )
        let topPadding = max(116, stageSize.height * 0.17)
        let bottomPadding = max(108, stageSize.height * 0.16)
        let sidePadding = max(38, stageSize.width * 0.10)
        let xRange = sidePadding...max(sidePadding, stageSize.width - sidePadding)
        let yRange = topPadding...max(topPadding, stageSize.height - bottomPadding)
        var position = CGPoint(x: CGFloat.random(in: xRange), y: CGFloat.random(in: yRange))

        for _ in 0..<14 {
            let candidate = CGPoint(
                x: CGFloat.random(in: xRange),
                y: CGFloat.random(in: yRange)
            )
            if canPlaceTarget(kind, at: candidate) {
                position = candidate
                break
            }
        }

        poops.append(StompTarget(
            position: position,
            kind: kind,
            createdAt: date,
            lifetime: kind.lifetime,
            seed: Double.random(in: 0...1000)
        ))
    }

    private func beginWave(_ wave: StompGameWave, at date: Date) {
        currentWave = wave
        waveAnnouncementUntil = date.addingTimeInterval(waveAnnouncementDuration)
        poops.removeAll()
        combo = 0
        lastSpawnDate = date
        InteractionFeedback.play(sound: .achievement, haptic: .medium)
    }

    private func removeExpiredTargets(at date: Date) {
        let expiredTargets = poops.filter { date.timeIntervalSince($0.createdAt) > $0.lifetime }
        guard !expiredTargets.isEmpty else { return }

        poops.removeAll { target in
            expiredTargets.contains { $0.id == target.id }
        }

        let escapedTargets = expiredTargets.filter(\.kind.reducesCleanlinessWhenEscaped)
        guard !escapedTargets.isEmpty else { return }

        let penalty = min(escapedTargets.count * 4, 16)
        cleanliness = max(0, cleanliness - penalty)
        escapedCount += escapedTargets.count
        combo = 0
        bursts.append(StompBurst(
            position: CGPoint(x: max(stageSize.width / 2, 1), y: max(stageSize.height * 0.42, 1)),
            text: "漏掉了 -\(penalty)%",
            color: .orange,
            createdAt: date,
            seed: Double.random(in: 0...1000)
        ))
        Haptics.play(.soft)
    }

    private func canPlaceTarget(_ kind: StompTargetKind, at position: CGPoint) -> Bool {
        poops.allSatisfy { target in
            distance(target.position, position) >= minimumSpacing(between: kind, and: target.kind)
        }
    }

    private func minimumSpacing(between first: StompTargetKind, and second: StompTargetKind) -> CGFloat {
        let safetyGap: CGFloat = (first == .mine || second == .mine) ? 34 : 18
        return first.radius + second.radius + safetyGap
    }

    private func attemptStomp(at location: CGPoint, date: Date) {
        guard phase == .playing,
              !isFinished,
              waveAnnouncementUntil <= date,
              date.timeIntervalSince(lastStompAttemptDate) >= stompCooldown else { return }

        lastStompAttemptDate = date

        let clamped = CGPoint(
            x: min(max(location.x, 28), max(stageSize.width - 28, 28)),
            y: min(max(location.y, 88), max(stageSize.height - 36, 88))
        )
        withAnimation(.spring(response: 0.18, dampingFraction: 0.62)) {
            bootPosition = clamped
        }

        bootResetTask?.cancel()
        bootResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(270))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.12)) {
                bootPosition = nil
            }
        }

        let hitTargets = poops
            .filter { distance($0.position, clamped) <= stompRadius + $0.kind.radius * 0.22 }
            .sorted { $0.kind.stompPriority < $1.kind.stompPriority }

        guard !hitTargets.isEmpty else {
            combo = 0
            bursts.append(StompBurst(
                position: clamped,
                text: "落空",
                color: .secondary,
                createdAt: date,
                seed: Double.random(in: 0...1000)
            ))
            InteractionFeedback.play(sound: .tap, haptic: .soft)
            return
        }

        var resolvedCount = 0
        for target in hitTargets where poops.contains(where: { $0.id == target.id }) {
            hitTarget(target, at: date)
            resolvedCount += 1
        }

        if resolvedCount >= 2 {
            bursts.append(StompBurst(
                position: clamped,
                text: "一脚 x\(resolvedCount)",
                color: .pink,
                createdAt: date,
                seed: Double.random(in: 0...1000)
            ))
        }
    }

    private func hitTarget(_ target: StompTarget, at date: Date) {
        if target.kind.isPowerUp {
            collectPowerUp(target, at: date)
        } else if target.kind == .mine {
            triggerMine(target, at: date)
        } else {
            stomp(target, at: date)
        }
    }

    private func stomp(_ target: StompTarget, at date: Date) {
        poops.removeAll { $0.id == target.id }

        let nextCombo = date.timeIntervalSince(lastStompDate) <= 1.25 ? combo + 1 : 1
        if nextCombo == 8 || (nextCombo > 8 && nextCombo.isMultiple(of: 12)) {
            triggerFever(at: date)
        }

        let feverBonus = isFeverActive(at: date) ? 1 : 0
        let multiplier = min(5, 1 + (nextCombo - 1) / 4 + feverBonus)
        let earned = target.kind.points * multiplier

        combo = nextCombo
        maxCombo = max(maxCombo, nextCombo)
        lastStompDate = date
        score += earned
        stompCount += 1

        bursts.append(StompBurst(
            position: target.position,
            text: "+\(earned)",
            color: target.kind.burstColor,
            createdAt: date,
            seed: target.seed
        ))

        if target.kind == .golden {
            InteractionFeedback.reward()
        } else {
            InteractionFeedback.play(sound: .small, haptic: .light)
        }

        if target.kind == .rainbow {
            for _ in 0..<2 {
                spawnTarget(at: date)
            }
        }
    }

    private func collectPowerUp(_ target: StompTarget, at date: Date) {
        poops.removeAll { $0.id == target.id }
        powerUpCount += 1

        switch target.kind {
        case .brush:
            let clearedTargets = poops.filter { !$0.kind.isHazard }
            let clearedScore = max(12, clearedTargets.count * 8)
            poops.removeAll { !$0.kind.isHazard }
            score += clearedScore
            bursts.append(StompBurst(
                position: target.position,
                text: "刷刷 +\(clearedScore)",
                color: .poopAccent,
                createdAt: date,
                seed: target.seed
            ))
            InteractionFeedback.reward()
        case .bubble:
            shieldUntil = max(shieldUntil, date).addingTimeInterval(shieldUntil > date ? 4 : 8)
            bursts.append(StompBurst(
                position: target.position,
                text: "泡泡护盾",
                color: .cyan,
                createdAt: date,
                seed: target.seed
            ))
            InteractionFeedback.play(sound: .achievement, haptic: .success)
        default:
            break
        }
    }

    private func triggerMine(_ target: StompTarget, at date: Date) {
        poops.removeAll { $0.id == target.id }

        if isShieldActive(at: date) {
            shieldUntil = Date.distantPast
            score += 5
            bursts.append(StompBurst(
                position: target.position,
                text: "泡泡挡住 +5",
                color: .cyan,
                createdAt: date,
                seed: target.seed
            ))
            InteractionFeedback.play(sound: .reward, haptic: .medium)
            return
        }

        combo = 0
        mineMistakeCount += 1
        score = max(0, score - 10)
        cleanliness = max(0, cleanliness - 12)

        bursts.append(StompBurst(
            position: target.position,
            text: "-10★\n-12%清洁",
            color: .red,
            createdAt: date,
            seed: target.seed
        ))

        SoundManager.shared.playMineWarning()
        Haptics.play(.heavy)

    }

    private func triggerFever(at date: Date) {
        let baseline = max(feverUntil, date)
        feverUntil = baseline.addingTimeInterval(6)
        feverCount += 1
        bursts.append(StompBurst(
            position: CGPoint(x: max(stageSize.width / 2, 1), y: max(stageSize.height * 0.34, 1)),
            text: "连击狂热！",
            color: .pink,
            createdAt: date,
            seed: Double.random(in: 0...1000)
        ))
        InteractionFeedback.reward()
    }

    private func finishGame(at date: Date) {
        guard !isFinished else { return }

        isFinished = true
        phase = .finished
        SoundManager.shared.stopPoopStompMusic()
        let rank = PoopStompGameRank.evaluate(
            cleanliness: cleanliness,
            maxCombo: maxCombo,
            mineMistakes: mineMistakeCount
        )
        let sticker = stickerForPerformance(
            score: score,
            stompCount: stompCount,
            maxCombo: maxCombo,
            rank: rank
        )
        let final = PoopStompGameResult(
            score: score,
            stompCount: stompCount,
            maxCombo: maxCombo,
            duration: min(gameElapsed(at: date), session.duration),
            cleanliness: cleanliness,
            rank: rank,
            sticker: sticker
        )
        stickerUnlock = recordFinalResult(final)
        resultReport = makeResultReport(for: final)
        result = final
        bootPosition = nil
        InteractionFeedback.play(sound: .reward, haptic: .success)
    }

    private func recordFinalResult(_ final: PoopStompGameResult) -> PoopStompStickerUnlock? {
        guard !didRecordResult else { return stickerUnlock }
        didRecordResult = true
        return onFinished(final)
    }

    private func togglePause(at date: Date) {
        if phase == .paused {
            resumeGame(at: date)
        } else if phase == .playing {
            pauseGame(at: date)
        }
    }

    private func pauseGame(at date: Date) {
        guard phase == .playing else { return }

        phase = .paused
        pausedAt = date
        SoundManager.shared.stopPoopStompMusic()
        Haptics.play(.soft)
    }

    private func resumeGame(at date: Date) {
        guard phase == .paused else { return }

        if let pausedAt {
            accumulatedPause += date.timeIntervalSince(pausedAt)
        }
        pausedAt = nil
        phase = .playing
        SoundManager.shared.startPoopStompMusic()
        InteractionFeedback.play(sound: .tap, haptic: .light)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if phase == .countdown {
                countdownStartedAt = .now
            }
        case .inactive, .background:
            pauseGame(at: .now)
            SoundManager.shared.stopPoopStompMusic()
        @unknown default:
            break
        }
    }

    private func gameElapsed(at date: Date) -> TimeInterval {
        guard phase != .countdown else { return 0 }

        let effectiveDate = phase == .paused ? (pausedAt ?? date) : date
        return max(effectiveDate.timeIntervalSince(startDate) - accumulatedPause, 0)
    }

    private func countdownNumber(at date: Date) -> Int {
        let remaining = max(countdownDuration - date.timeIntervalSince(countdownStartedAt), 0)
        return max(Int(ceil(remaining)), 1)
    }

    private func isFeverActive(at date: Date) -> Bool {
        feverUntil > date
    }

    private func isShieldActive(at date: Date) -> Bool {
        shieldUntil > date
    }

    private func makeResultReport(for result: PoopStompGameResult) -> String {
        if result.rank == .s {
            return "S 级闪耀清扫！落脚又快又准。"
        }
        if result.score > previousHighScore, previousHighScore > 0 {
            return "新纪录！比历史最高多 \(result.score - previousHighScore) 星。"
        }
        if escapedCount == 0, mineMistakeCount == 0 {
            return "一个目标都没漏掉，清扫路线稳稳的。"
        }
        if feverCount > 0 {
            return "触发 \(feverCount) 次连击狂热，今天的靴子很有节奏。"
        }
        if powerUpCount > 0 {
            return "用了 \(powerUpCount) 个清洁道具，清扫队长上线。"
        }
        if mineMistakeCount == 0, result.stompCount >= 12 {
            return "全程避开地雷，稳稳收工。"
        }
        return "踩中 \(result.stompCount) 个目标，明天还能继续刷新纪录。"
    }

    private func stickerForPerformance(
        score: Int,
        stompCount: Int,
        maxCombo: Int,
        rank: PoopStompGameRank
    ) -> PoopStompSticker {
        if maxCombo >= 12 {
            return .comboLightning
        }
        if feverCount > 0 {
            return .rainbowRush
        }
        if powerUpCount >= 2 {
            return .cleanKit
        }
        if mineMistakeCount == 0, stompCount >= 12 {
            return .bubbleGuard
        }
        if rank == .s || score >= max(previousHighScore, 260) {
            return .goldenBoot
        }
        return .cleanCaptain
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}

private enum StompGamePhase: Equatable {
    case countdown
    case playing
    case paused
    case finished
}

private enum StompGameWave: Int, Equatable {
    case warmUp = 1
    case choice = 2
    case finale = 3

    var title: String {
        switch self {
        case .warmUp:
            return "热身清扫"
        case .choice:
            return "小心地雷"
        case .finale:
            return "闪耀冲刺"
        }
    }

    var subtitle: String {
        switch self {
        case .warmUp:
            return "点一下，让靴子落下"
        case .choice:
            return "一脚多踩，避开红色地雷"
        case .finale:
            return "抓住道具，冲出最高连击"
        }
    }

    var endsAt: TimeInterval {
        switch self {
        case .warmUp:
            return 12
        case .choice:
            return 29
        case .finale:
            return PoopStompGameGate.dailyDuration
        }
    }

    var spawnInterval: TimeInterval {
        switch self {
        case .warmUp:
            return 0.76
        case .choice:
            return 0.60
        case .finale:
            return 0.48
        }
    }

    var targetLimit: Int {
        switch self {
        case .warmUp:
            return 5
        case .choice:
            return 7
        case .finale:
            return 9
        }
    }

    var next: StompGameWave? {
        switch self {
        case .warmUp:
            return .choice
        case .choice:
            return .finale
        case .finale:
            return nil
        }
    }
}

private struct StompTarget: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    let kind: StompTargetKind
    let createdAt: Date
    let lifetime: TimeInterval
    let seed: Double
}

private enum StompTargetKind: Equatable {
    case normal
    case sleepy
    case golden
    case rainbow
    case mine
    case brush
    case bubble

    var points: Int {
        switch self {
        case .normal:
            return 10
        case .sleepy:
            return 16
        case .golden:
            return 35
        case .rainbow:
            return 24
        case .mine:
            return 0
        case .brush, .bubble:
            return 0
        }
    }

    var radius: CGFloat {
        switch self {
        case .normal:
            return 31
        case .sleepy:
            return 25
        case .golden:
            return 29
        case .rainbow:
            return 28
        case .mine:
            return 30
        case .brush:
            return 27
        case .bubble:
            return 26
        }
    }

    var lifetime: TimeInterval {
        switch self {
        case .normal:
            return 3.1
        case .sleepy:
            return 2.1
        case .golden:
            return 1.55
        case .rainbow:
            return 1.95
        case .mine:
            return 2.2
        case .brush:
            return 2.4
        case .bubble:
            return 2.6
        }
    }

    var stompPriority: Int {
        switch self {
        case .bubble:
            return 0
        case .normal, .sleepy, .golden, .rainbow:
            return 1
        case .brush:
            return 2
        case .mine:
            return 3
        }
    }

    var burstColor: Color {
        switch self {
        case .normal:
            return .poopAccent
        case .sleepy:
            return .cyan
        case .golden:
            return .yellow
        case .rainbow:
            return .pink
        case .mine:
            return .red
        case .brush:
            return .poopAccent
        case .bubble:
            return .cyan
        }
    }

    var isPowerUp: Bool {
        self == .brush || self == .bubble
    }

    var isHazard: Bool {
        self == .mine
    }

    var reducesCleanlinessWhenEscaped: Bool {
        switch self {
        case .normal, .sleepy, .golden, .rainbow:
            return true
        case .mine, .brush, .bubble:
            return false
        }
    }

    static func random(elapsed: TimeInterval, wave: StompGameWave, isFeverActive: Bool) -> StompTargetKind {
        let roll = Double.random(in: 0...1)

        if isFeverActive {
            if roll < 0.12 { return .bubble }
            if roll < 0.24 { return .brush }
            if roll < 0.55 { return .golden }
            if roll < 0.82 { return .rainbow }
            return .normal
        }

        switch wave {
        case .warmUp:
            if roll < 0.14 { return .golden }
            if elapsed > 6, roll < 0.25 { return .rainbow }
            if roll < 0.42 { return .sleepy }
            return .normal
        case .choice:
            if roll < 0.08 { return .brush }
            if roll < 0.15 { return .bubble }
            if roll < 0.31 { return .mine }
            if roll < 0.46 { return .golden }
            if roll < 0.62 { return .rainbow }
            if roll < 0.80 { return .sleepy }
            return .normal
        case .finale:
            if roll < 0.07 { return .brush }
            if roll < 0.14 { return .bubble }
            if roll < 0.33 { return .mine }
            if roll < 0.49 { return .golden }
            if roll < 0.71 { return .rainbow }
            if roll < 0.86 { return .sleepy }
            return .normal
        }
    }
}

private struct StompBurst: Identifiable {
    let id = UUID()
    let position: CGPoint
    let text: String
    let color: Color
    let createdAt: Date
    let seed: Double
}

private struct StompGameHUD: View {
    let remaining: TimeInterval
    let score: Int
    let combo: Int
    let cleanliness: Int
    let wave: StompGameWave
    let isPaused: Bool
    let isFeverActive: Bool
    let shieldRemaining: TimeInterval
    let onPauseToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                HUDCapsule(systemImage: "timer", text: timeText, tint: .poopAccent)
                HUDCapsule(systemImage: "star.fill", text: "\(score)", tint: .yellow)

                Spacer(minLength: 0)

                HUDCapsule(systemImage: "drop.fill", text: "\(cleanliness)%", tint: cleanlinessTint)
                HUDIconButton(systemImage: isPaused ? "play.fill" : "pause.fill", action: onPauseToggle)
            }

            HStack(spacing: 8) {
                HUDCapsule(systemImage: "flag.checkered", text: "第\(wave.rawValue)/3波", tint: .orange)

                if combo >= 2 {
                    HUDCapsule(systemImage: "bolt.fill", text: "x\(combo)", tint: .pink)
                        .transition(.scale.combined(with: .opacity))
                }

                if isFeverActive {
                    HUDCapsule(systemImage: "sparkles", text: "狂热", tint: .pink)
                        .transition(.scale.combined(with: .opacity))
                }

                if shieldRemaining > 0 {
                    HUDCapsule(systemImage: "shield.fill", text: "\(Int(ceil(shieldRemaining)))s", tint: .cyan)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: combo)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isFeverActive)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: shieldRemaining > 0)
        .animation(.easeOut(duration: 0.18), value: cleanliness)
    }

    private var timeText: String {
        let totalSeconds = max(Int(ceil(remaining)), 0)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var cleanlinessTint: Color {
        if cleanliness >= 75 { return .cyan }
        if cleanliness >= 50 { return .orange }
        return .red
    }
}

private struct HUDIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.poopAccent.opacity(0.34), lineWidth: 1.4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemImage == "play.fill" ? "继续游戏" : "暂停游戏")
    }
}

private struct StompCountdownOverlay: View {
    let value: Int
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text(value > 0 ? "\(value)" : "开踩！")
                .font(.system(size: 82, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.poopAccent)
                .contentTransition(.numericText())
                .scaleEffect(reduceMotion ? 1 : 1.0 + CGFloat(value % 2) * 0.08)

            Text("点击便便群，让靴子落下")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1.2)
        }
        .shadow(color: Color.poopBrown.opacity(0.16), radius: 24, y: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("倒计时 \(value)")
    }
}

private struct StompWaveAnnouncementOverlay: View {
    let wave: StompGameWave
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("第 \(wave.rawValue) 波")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.poopAccent)

            Text(wave.title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)

            Text(wave.subtitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1.2)
        }
        .scaleEffect(reduceMotion ? 1 : 1.04)
        .shadow(color: Color.poopBrown.opacity(0.16), radius: 20, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(wave.rawValue) 波，\(wave.title)，\(wave.subtitle)")
    }
}

private struct StompPauseOverlay: View {
    let onResume: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.22))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(Color.poopAccent)

                Text("先歇一下")
                    .font(.system(size: 30, weight: .black, design: .rounded))

                Text("计时已暂停，回来继续踩。")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Button(action: onResume) {
                    Label("继续挑战", systemImage: "play.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.poopAccent.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1.2)
            }
            .padding(22)
        }
    }
}

private struct StompFeverOverlay: View {
    let date: Date
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let phase = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 2.4))

            ZStack {
                RadialGradient(
                    colors: [
                        .pink.opacity(0.28),
                        .yellow.opacity(0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: min(proxy.size.width, proxy.size.height) * 0.65
                )

                ForEach(0..<9, id: \.self) { index in
                    Text(index.isMultiple(of: 2) ? "✨" : "🌈")
                        .font(.system(size: 20 + CGFloat(index % 3) * 5))
                        .position(
                            x: proxy.size.width * (0.12 + 0.76 * CGFloat(index) / 8),
                            y: proxy.size.height * (0.24 + 0.52 * CGFloat((index * 31) % 100) / 100) + phase * 10
                        )
                        .opacity(0.30)
                }
            }
        }
    }
}

private struct HUDCapsule: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        Label {
            Text(text)
                .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .black))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.38), lineWidth: 1.5)
        }
    }
}

private struct StompTargetView: View {
    let target: StompTarget
    let date: Date
    let reduceMotion: Bool

    var body: some View {
        let age = date.timeIntervalSince(target.createdAt)
        let fadeIn = min(age / 0.18, 1)
        let fadeOut = max(0, min((target.lifetime - age) / 0.45, 1))
        let urgent = target.lifetime - age < 0.62
        let wobble = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 4.0 + target.seed)) * 5
        let hop = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 7.2 + target.seed * 0.7)) * 2.5

        ZStack(alignment: .topTrailing) {
            Group {
                if target.kind == .mine {
                    CuteMineView(date: date, seed: target.seed, reduceMotion: reduceMotion)
                } else if target.kind.isPowerUp {
                    PowerUpTargetView(kind: target.kind, date: date, reduceMotion: reduceMotion)
                } else {
                    CuteStompPoop(kind: target.kind)
                }
            }

            if urgent, target.kind != .mine {
                Text(target.kind.isPowerUp ? "快！" : "💧")
                    .font(.system(size: target.kind.isPowerUp ? 13 : 16, weight: .black, design: .rounded))
                    .foregroundStyle(target.kind.isPowerUp ? .white : .cyan)
                    .padding(.horizontal, target.kind.isPowerUp ? 6 : 0)
                    .padding(.vertical, target.kind.isPowerUp ? 3 : 0)
                    .background(target.kind.isPowerUp ? Color.red.opacity(0.72) : Color.clear, in: Capsule())
                    .offset(x: 12, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: target.kind.radius * 2.35, height: target.kind.radius * 2.35)
        .scaleEffect(0.68 + 0.32 * fadeIn)
        .rotationEffect(.degrees(Double(wobble * 0.8)))
        .position(x: target.position.x + wobble, y: target.position.y + hop)
        .opacity(fadeIn * fadeOut)
        .shadow(color: target.kind.burstColor.opacity(0.18 * fadeOut), radius: 10, y: 7)
    }
}

private struct CuteMineView: View {
    let date: Date
    let seed: Double
    let reduceMotion: Bool

    var body: some View {
        let pulse = reduceMotion ? 1 : 0.92 + CGFloat(sin(date.timeIntervalSinceReferenceDate * 9 + seed)) * 0.08

        ZStack {
            Circle()
                .fill(.red.opacity(0.13))
                .scaleEffect(pulse * 1.34)

            MineSpikesShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.08, blue: 0.11),
                            Color(red: 0.22, green: 0.24, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    MineSpikesShape()
                        .stroke(.white.opacity(0.28), lineWidth: 1.6)
                }
                .scaleEffect(pulse)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.26, green: 0.28, blue: 0.34),
                            Color(red: 0.05, green: 0.06, blue: 0.08)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 34
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 2)
                }

            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.34))
                    .frame(width: 4.5, height: 4.5)
                    .offset(y: -18)
                    .rotationEffect(.degrees(Double(index) * 60))
            }

            Circle()
                .fill(Color.red.gradient)
                .frame(width: 23, height: 23)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.82), lineWidth: 1.6)
                }
                .shadow(color: .red.opacity(0.38), radius: 7)

            Text("!")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.24), radius: 1, y: 1)

            Capsule()
                .fill(Color(red: 0.05, green: 0.06, blue: 0.08))
                .frame(width: 19, height: 9)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
                .rotationEffect(.degrees(22))
                .offset(x: 20, y: -25)
        }
        .accessibilityLabel("限时地雷")
    }
}

private struct PowerUpTargetView: View {
    let kind: StompTargetKind
    let date: Date
    let reduceMotion: Bool

    var body: some View {
        let pulse = reduceMotion ? 1 : 0.96 + CGFloat(sin(date.timeIntervalSinceReferenceDate * 5.8)) * 0.06

        ZStack {
            Circle()
                .fill(backgroundGradient)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.72), lineWidth: 2)
                }
                .shadow(color: tint.opacity(0.26), radius: 12, y: 7)

            if kind == .brush {
                BrushPowerGlyph()
                    .frame(width: 48, height: 48)
            } else {
                BubblePowerGlyph()
                    .frame(width: 48, height: 48)
            }
        }
        .scaleEffect(pulse)
        .accessibilityLabel(kind == .brush ? "清屏刷子" : "泡泡护盾")
    }

    private var tint: Color {
        kind == .brush ? .poopAccent : .cyan
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: kind == .brush
                ? [.white, .poopLightGreen, .poopAccent.opacity(0.72)]
                : [.white, .cyan.opacity(0.54), .blue.opacity(0.46)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct BrushPowerGlyph: View {
    var body: some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color.poopAccent : Color.poopLightGreen)
                        .frame(width: 4, height: index.isMultiple(of: 3) ? 24 : 18)
                }
            }
            .offset(y: 8)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.poopAccent.gradient)
                .frame(width: 38, height: 15)
                .offset(y: -6)

            Capsule()
                .fill(Color.poopBrown.gradient)
                .frame(width: 10, height: 38)
                .rotationEffect(.degrees(-36))
                .offset(x: -13, y: -20)
        }
        .accessibilityHidden(true)
    }
}

private struct BubblePowerGlyph: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.28))
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.78), lineWidth: 1.3)
                    }
                    .frame(width: 12 + CGFloat(index % 3) * 6)
                    .offset(
                        x: CGFloat([-14, 11, -2, 16, -17][index]),
                        y: CGFloat([-9, -15, 3, 13, 16][index])
                    )
            }

            Image(systemName: "shield.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .cyan.opacity(0.48), radius: 5)
        }
        .accessibilityHidden(true)
    }
}

private struct MineSpikesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = side * 0.48
        let innerRadius = side * 0.34
        let pointCount = 24
        var path = Path()

        for index in 0..<pointCount {
            let angle = -Double.pi / 2 + Double(index) * Double.pi * 2 / Double(pointCount)
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct CuteStompPoop: View {
    let kind: StompTargetKind

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                PoopPileShape()
                    .fill(fillGradient)
                    .overlay {
                        PoopPileShape()
                            .stroke(.white.opacity(kind == .golden ? 0.70 : 0.38), lineWidth: side * 0.035)
                    }

                VStack(spacing: side * 0.045) {
                    HStack(spacing: side * 0.13) {
                        eye
                        eye
                    }

                    mouth
                }
                .frame(width: side * 0.55, height: side * 0.26)
                .offset(y: side * 0.13)

                if kind == .golden {
                    Text("✦")
                        .font(.system(size: side * 0.28, weight: .black))
                        .foregroundStyle(.white)
                        .offset(x: side * 0.25, y: -side * 0.25)
                } else if kind == .rainbow {
                    Text("✿")
                        .font(.system(size: side * 0.24, weight: .black))
                        .foregroundStyle(.pink)
                        .offset(x: -side * 0.26, y: -side * 0.24)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var fillGradient: LinearGradient {
        switch kind {
        case .normal, .sleepy, .mine, .brush, .bubble:
            return LinearGradient(
                colors: [.poopBrownLight, .poopBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .golden:
            return LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .rainbow:
            return LinearGradient(
                colors: [.poopBrownLight, .pink.opacity(0.74), .poopAccent.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.black.opacity(0.78))
            .frame(width: 8, height: kind == .sleepy ? 3 : 11)
    }

    private var mouth: some View {
        Group {
            if kind == .sleepy {
                Capsule()
                    .stroke(.black.opacity(0.68), lineWidth: 2.8)
                    .frame(width: 17, height: 6)
            } else {
                ArcSmile()
                    .stroke(.black.opacity(0.72), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                    .frame(width: 24, height: 14)
            }
        }
    }
}

private struct PoopPileShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let originX = rect.midX - side / 2
        let originY = rect.midY - side / 2
        var path = Path()

        path.addEllipse(in: CGRect(x: originX + side * 0.12, y: originY + side * 0.58, width: side * 0.76, height: side * 0.30))
        path.addEllipse(in: CGRect(x: originX + side * 0.20, y: originY + side * 0.38, width: side * 0.62, height: side * 0.30))
        path.addEllipse(in: CGRect(x: originX + side * 0.31, y: originY + side * 0.22, width: side * 0.43, height: side * 0.25))
        path.addEllipse(in: CGRect(x: originX + side * 0.46, y: originY + side * 0.10, width: side * 0.18, height: side * 0.18))
        return path
    }
}

private struct BootCursorView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.mint, .poopAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 62)
                .offset(x: -4, y: -9)

            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.poopDeepGreen)
                .frame(width: 66, height: 24)
                .offset(x: 8, y: 0)

            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: 32, height: 6)
                .offset(x: -5, y: -49)

            Capsule()
                .fill(.black.opacity(0.18))
                .frame(width: 68, height: 8)
                .offset(x: 9, y: 5)
        }
        .rotationEffect(.degrees(-17))
        .accessibilityHidden(true)
    }
}

private struct StompLandingView: View {
    let radius: CGFloat
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.poopAccent.opacity(0.12))
                .overlay {
                    Circle()
                        .stroke(
                            Color.poopAccent.opacity(0.58),
                            style: StrokeStyle(lineWidth: 2.5, dash: [7, 5])
                        )
                }
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(reduceMotion ? 1 : 1.06)

            BootCursorView()
                .frame(width: 82, height: 82)
                .shadow(color: Color.poopBrown.opacity(0.22), radius: 14, y: 10)
        }
        .frame(width: radius * 2, height: radius * 2)
        .accessibilityHidden(true)
    }
}

private struct StompBurstView: View {
    let burst: StompBurst
    let date: Date
    let reduceMotion: Bool

    var body: some View {
        let age = date.timeIntervalSince(burst.createdAt)
        let progress = min(max(age / 0.82, 0), 1)
        let opacity = max(0, 1 - progress)

        ZStack {
            if !reduceMotion {
                ForEach(0..<7, id: \.self) { index in
                    let angle = Double(index) / 7.0 * Double.pi * 2 + burst.seed
                    let distance = CGFloat(20 + progress * 54)
                    Text(index.isMultiple(of: 2) ? "✨" : "✦")
                        .font(.system(size: 14 + CGFloat(index % 3) * 2, weight: .black))
                        .foregroundStyle(burst.color)
                        .offset(
                            x: CGFloat(cos(angle)) * distance,
                            y: CGFloat(sin(angle)) * distance - CGFloat(progress * 18)
                        )
                        .opacity(opacity)
                }
            }

            Text(burst.text)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(burst.color)
                .shadow(color: .white.opacity(0.9), radius: 0, x: 0, y: 1)
                .offset(y: -CGFloat(progress * (reduceMotion ? 18 : 54)))
                .opacity(opacity)
        }
        .position(burst.position)
    }
}

private struct StompResultOverlay: View {
    let result: PoopStompGameResult
    let previousHighScore: Int
    let report: String
    let stickerUnlock: PoopStompStickerUnlock?
    let onDone: () -> Void

    private var isNewHighScore: Bool {
        result.score > previousHighScore
    }

    private var rankTint: Color {
        switch result.rank {
        case .s:
            return .yellow
        case .a:
            return .poopAccent
        case .b:
            return .cyan
        case .c:
            return .orange
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.30))
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    Text(result.rank.rawValue)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(rankTint)
                        .frame(width: 82, height: 82)
                        .background(rankTint.opacity(0.14), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(rankTint.opacity(0.42), lineWidth: 2)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("今日清扫完成！")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text(result.rank.title)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(rankTint)

                        Label("\(result.score) 星", systemImage: "star.fill")
                            .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.poopAccent)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 9) {
                    ResultMetric(title: "历史最高", value: "\(max(previousHighScore, result.score))")
                    ResultMetric(title: "清洁度", value: "\(result.cleanliness)%")
                    ResultMetric(title: "连击", value: "x\(max(result.maxCombo, 1))")
                }

                Text("踩中 \(result.stompCount) 个目标 · 用时 \(Int(result.duration.rounded())) 秒")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                if isNewHighScore {
                    Label(previousHighScore > 0 ? "新纪录 +\(result.score - previousHighScore)" : "第一份挑战纪录", systemImage: "crown.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.14), in: Capsule())
                }

                if let stickerUnlock {
                    StompStickerUnlockView(unlock: stickerUnlock)
                }

                Text(report)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)

                Button(action: onDone) {
                    Label("收下今日星星", systemImage: "star.circle.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.poopAccent.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1.2)
            }
            .padding(22)
        }
    }
}

private struct ResultMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StompStickerUnlockView: View {
    let unlock: PoopStompStickerUnlock

    var body: some View {
        HStack(spacing: 10) {
            Text(unlock.sticker.symbol)
                .font(.system(size: 30))
                .frame(width: 48, height: 48)
                .background(Color.poopCream, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.poopAccent.opacity(0.28), lineWidth: 1.4)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(unlock.isNew ? "新贴纸解锁" : "今日贴纸")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.poopAccent)
                Text(unlock.sticker.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                Text("图鉴 \(unlock.totalUnlocked)/\(unlock.totalAvailable)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.poopAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unlock.isNew ? "新贴纸解锁" : "今日贴纸")，\(unlock.sticker.title)，图鉴 \(unlock.totalUnlocked)/\(unlock.totalAvailable)")
    }
}

private struct StompFieldBackground: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(hex: "#BDEBFF"),
                    Color.poopCream.opacity(0.92),
                    Color(hex: "#DCF6C9")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                Path { path in
                    let height = proxy.size.height
                    let width = proxy.size.width
                    path.move(to: CGPoint(x: 0, y: height * 0.73))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.70),
                        control1: CGPoint(x: width * 0.28, y: height * 0.66),
                        control2: CGPoint(x: width * 0.68, y: height * 0.78)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(Color.poopLightGreen.opacity(0.72))

                Path { path in
                    let height = proxy.size.height
                    let width = proxy.size.width
                    path.move(to: CGPoint(x: 0, y: height * 0.84))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.82),
                        control1: CGPoint(x: width * 0.32, y: height * 0.78),
                        control2: CGPoint(x: width * 0.64, y: height * 0.90)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(Color.poopMediumGreen.opacity(0.58))
            }
            .ignoresSafeArea()
        }
    }
}

private struct StompTrackMarks: View {
    let date: Date
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ForEach(0..<10, id: \.self) { index in
                let offset = CGFloat(index) / 9
                let drift = reduceMotion ? 0 : CGFloat(sin(date.timeIntervalSinceReferenceDate * 0.45 + Double(index))) * 5
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.22) : Color.poopAccent.opacity(0.13))
                    .frame(width: 46 + CGFloat(index % 3) * 12, height: 9)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 8))
                    .position(
                        x: width * (0.10 + 0.80 * offset),
                        y: height * (0.42 + 0.44 * CGFloat((index * 37) % 100) / 100) + drift
                    )
            }
        }
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

#Preview("Poop Stomp") {
    PoopStompGameView(
        session: PoopStompGameSession(
            profileID: ProfileStore.defaultProfileID,
            dayKey: Calendar.poopDiary.dayKey(for: .now),
            streak: 5,
            duration: 18
        )
    ) { result in
        PoopStompStickerUnlock(
            sticker: result.sticker,
            isNew: true,
            totalUnlocked: 1,
            totalAvailable: PoopStompSticker.allCases.count
        )
    }
}
