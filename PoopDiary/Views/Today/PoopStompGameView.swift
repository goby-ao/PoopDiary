import SwiftUI

struct PoopStompGameView: View {
    @Environment(\.dismiss) private var dismiss

    let session: PoopStompGameSession
    let onFinished: (PoopStompGameResult) -> Void

    @State private var startDate = Date.now
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
    @State private var timePenalty: TimeInterval = 0
    @State private var isFinished = false
    @State private var result: PoopStompGameResult?

    private let tick = Timer.publish(every: 0.14, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let date = timeline.date
                let elapsed = date.timeIntervalSince(startDate)
                let adjustedElapsed = elapsed + timePenalty
                let remaining = max(session.duration - adjustedElapsed, 0)

                ZStack {
                    StompFieldBackground()

                    StompTrackMarks(date: date)
                        .allowsHitTesting(false)

                    ForEach(poops) { target in
                        StompTargetView(target: target, date: date)
                            .allowsHitTesting(false)
                    }

                    ForEach(bursts) { burst in
                        StompBurstView(burst: burst, date: date)
                            .allowsHitTesting(false)
                    }

                    if let bootPosition {
                        BootCursorView()
                            .frame(width: 86, height: 86)
                            .position(bootPosition)
                            .shadow(color: Color.poopBrown.opacity(0.22), radius: 14, y: 10)
                            .allowsHitTesting(false)
                    }

                    StompGameHUD(
                        remaining: remaining,
                        score: score,
                        combo: combo,
                        streak: session.streak
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    if let result {
                        StompResultOverlay(result: result) {
                            InteractionFeedback.play(sound: .tap, haptic: .light)
                            onFinished(result)
                            dismiss()
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(20)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            moveBoot(to: value.location, at: Date.now)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                                bootPosition = nil
                            }
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
        .onDisappear {
            SoundManager.shared.stopPoopStompMusic()
        }
    }

    private func startGameIfNeeded(size: CGSize) {
        guard poops.isEmpty, score == 0, !isFinished else { return }

        startDate = .now
        lastSpawnDate = .distantPast
        stageSize = size
        for _ in 0..<5 {
            spawnTarget(at: .now)
        }
        SoundManager.shared.startPoopStompMusic()
        InteractionFeedback.play(sound: .achievement, haptic: .success)
    }

    private func updateGame(at date: Date) {
        guard !isFinished else { return }

        let adjustedElapsed = date.timeIntervalSince(startDate) + timePenalty
        if adjustedElapsed >= session.duration {
            finishGame(at: date)
            return
        }

        poops.removeAll { date.timeIntervalSince($0.createdAt) > $0.lifetime }
        bursts.removeAll { date.timeIntervalSince($0.createdAt) > 0.92 }

        let elapsed = adjustedElapsed
        let pace = min(elapsed / session.duration, 1)
        let streakBoost = min(max(session.streak - 3, 0), 3)
        let spawnInterval = max(0.24, 0.68 - pace * 0.26 - Double(streakBoost) * 0.045)
        let targetLimit = min(12, 6 + Int(elapsed / 22) + streakBoost)

        if poops.count < targetLimit, date.timeIntervalSince(lastSpawnDate) >= spawnInterval {
            spawnTarget(at: date)
            lastSpawnDate = date
        }
    }

    private func spawnTarget(at date: Date) {
        guard stageSize.width > 80, stageSize.height > 180 else { return }

        let kind = StompTargetKind.random(elapsed: date.timeIntervalSince(startDate), streak: session.streak)
        let topPadding = max(116, stageSize.height * 0.17)
        let bottomPadding = max(108, stageSize.height * 0.16)
        let sidePadding = max(38, stageSize.width * 0.10)
        let xRange = sidePadding...max(sidePadding, stageSize.width - sidePadding)
        let yRange = topPadding...max(topPadding, stageSize.height - bottomPadding)
        let position = CGPoint(
            x: CGFloat.random(in: xRange),
            y: CGFloat.random(in: yRange)
        )

        poops.append(StompTarget(
            position: position,
            kind: kind,
            createdAt: date,
            lifetime: kind.lifetime,
            seed: Double.random(in: 0...1000)
        ))
    }

    private func moveBoot(to location: CGPoint, at date: Date) {
        guard !isFinished else { return }

        let clamped = CGPoint(
            x: min(max(location.x, 28), max(stageSize.width - 28, 28)),
            y: min(max(location.y, 88), max(stageSize.height - 36, 88))
        )
        bootPosition = clamped

        guard let hit = poops.first(where: { distance($0.position, clamped) <= $0.hitRadius }) else {
            nudgeTargetsAway(from: clamped)
            return
        }

        hitTarget(hit, at: date)
    }

    private func hitTarget(_ target: StompTarget, at date: Date) {
        if target.kind == .mine {
            triggerMine(target, at: date)
        } else {
            stomp(target, at: date)
        }
    }

    private func stomp(_ target: StompTarget, at date: Date) {
        poops.removeAll { $0.id == target.id }

        let nextCombo = date.timeIntervalSince(lastStompDate) <= 1.25 ? combo + 1 : 1
        let multiplier = min(4, 1 + (nextCombo - 1) / 4)
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

    private func triggerMine(_ target: StompTarget, at date: Date) {
        poops.removeAll { $0.id == target.id }
        combo = 0
        score = max(0, score - 5)
        timePenalty += 5

        bursts.append(StompBurst(
            position: target.position,
            text: "-5★\n-5秒",
            color: .red,
            createdAt: date,
            seed: target.seed
        ))

        SoundManager.shared.playMineWarning()
        Haptics.play(.heavy)

        if date.timeIntervalSince(startDate) + timePenalty >= session.duration {
            finishGame(at: date)
        }
    }

    private func nudgeTargetsAway(from point: CGPoint) {
        poops = poops.map { target in
            guard target.kind != .mine else { return target }
            let d = distance(target.position, point)
            guard d > 0, d < target.kind.dodgeDistance else { return target }

            var nudged = target
            let push = (target.kind.dodgeDistance - d) * 0.26
            let dx = (target.position.x - point.x) / d
            let dy = (target.position.y - point.y) / d
            nudged.position.x = min(max(target.position.x + dx * push, 34), max(stageSize.width - 34, 34))
            nudged.position.y = min(max(target.position.y + dy * push, 112), max(stageSize.height - 86, 112))
            return nudged
        }
    }

    private func finishGame(at date: Date) {
        guard !isFinished else { return }

        isFinished = true
        SoundManager.shared.stopPoopStompMusic()
        let final = PoopStompGameResult(
            score: score,
            stompCount: stompCount,
            maxCombo: maxCombo,
            duration: min(date.timeIntervalSince(startDate) + timePenalty, session.duration)
        )
        result = final
        bootPosition = nil
        InteractionFeedback.play(sound: .reward, haptic: .success)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}

private struct StompTarget: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    let kind: StompTargetKind
    let createdAt: Date
    let lifetime: TimeInterval
    let seed: Double

    var hitRadius: CGFloat {
        if kind == .mine {
            return kind.radius + 16
        }
        return kind.radius + 21
    }
}

private enum StompTargetKind: Equatable {
    case normal
    case sleepy
    case golden
    case rainbow
    case mine

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
        }
    }

    var dodgeDistance: CGFloat {
        switch self {
        case .normal:
            return 120
        case .sleepy:
            return 142
        case .golden:
            return 156
        case .rainbow:
            return 150
        case .mine:
            return 0
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
        }
    }

    static func random(elapsed: TimeInterval, streak: Int) -> StompTargetKind {
        let roll = Double.random(in: 0...1)
        let streakBoost = min(Double(max(streak - 3, 0)) * 0.018, 0.06)
        var threshold = 0.0

        if elapsed > 8 {
            threshold += 0.15
            if roll < threshold {
                return .mine
            }
        }

        threshold += 0.10 + streakBoost
        if roll < threshold {
            return .golden
        }

        if elapsed > 18 {
            threshold += 0.18 + streakBoost
            if roll < threshold {
                return .rainbow
            }
        }

        if elapsed > 12, roll < threshold + 0.28 {
            return .sleepy
        }
        return .normal
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
    let streak: Int

    var body: some View {
        HStack(spacing: 9) {
            HUDCapsule(systemImage: "timer", text: timeText, tint: .poopAccent)
            HUDCapsule(systemImage: "star.fill", text: "\(score)", tint: .yellow)

            if combo >= 2 {
                HUDCapsule(systemImage: "bolt.fill", text: "x\(combo)", tint: .pink)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 0)

            HUDCapsule(systemImage: "flame.fill", text: "\(streak)天", tint: .orange)
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: combo)
    }

    private var timeText: String {
        let totalSeconds = max(Int(ceil(remaining)), 0)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
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

    var body: some View {
        let age = date.timeIntervalSince(target.createdAt)
        let fadeIn = min(age / 0.18, 1)
        let fadeOut = max(0, min((target.lifetime - age) / 0.45, 1))
        let wobble = CGFloat(sin(date.timeIntervalSinceReferenceDate * 4.0 + target.seed)) * 5
        let hop = CGFloat(sin(date.timeIntervalSinceReferenceDate * 7.2 + target.seed * 0.7)) * 2.5

        Group {
            if target.kind == .mine {
                CuteMineView(date: date, seed: target.seed)
            } else {
                CuteStompPoop(kind: target.kind)
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

    var body: some View {
        let pulse = 0.92 + CGFloat(sin(date.timeIntervalSinceReferenceDate * 9 + seed)) * 0.08

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
        case .normal, .sleepy, .mine:
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

private struct StompBurstView: View {
    let burst: StompBurst
    let date: Date

    var body: some View {
        let age = date.timeIntervalSince(burst.createdAt)
        let progress = min(max(age / 0.82, 0), 1)
        let opacity = max(0, 1 - progress)

        ZStack {
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

            Text(burst.text)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(burst.color)
                .shadow(color: .white.opacity(0.9), radius: 0, x: 0, y: 1)
                .offset(y: -CGFloat(progress * 54))
                .opacity(opacity)
        }
        .position(burst.position)
    }
}

private struct StompResultOverlay: View {
    let result: PoopStompGameResult
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.30))
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("💩✨")
                    .font(.system(size: 54))

                VStack(spacing: 8) {
                    Text("今日便便清扫完成！")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("踩中 \(result.stompCount) 个，最高连击 x\(max(result.maxCombo, 1))")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Text("\(result.score)")
                    .font(.system(size: 58, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.poopAccent)
                    .contentTransition(.numericText())

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
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1.2)
            }
            .padding(22)
        }
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

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ForEach(0..<10, id: \.self) { index in
                let offset = CGFloat(index) / 9
                let drift = CGFloat(sin(date.timeIntervalSinceReferenceDate * 0.45 + Double(index))) * 5
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
    ) { _ in }
}
