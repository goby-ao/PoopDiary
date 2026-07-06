import SwiftUI

struct CleanRitualRequest: Identifiable, Equatable {
    let id = UUID()
    let amount: PoopAmount
    let nickname: String
    let unlocksStompGame: Bool
}

struct CleanRitualOverlay: View {
    let request: CleanRitualRequest
    let onFinished: () -> Void

    @State private var phase: CleanRitualPhase = .celebrate
    @State private var phaseTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let isLarge = proxy.size.width >= 640
            let cardWidth = min(proxy.size.width - 28, isLarge ? 570 : 392)
            let cardHeight = max(340, min(proxy.size.height - 34, isLarge ? 600 : 536))

            ZStack {
                ritualBackdrop
                RitualFloatingJoy(isLarge: isLarge)

                ritualCard(isLarge: isLarge)
                    .frame(width: cardWidth, height: cardHeight)
                    .padding(.horizontal, 18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onAppear {
            startRitual()
        }
        .onDisappear {
            phaseTask?.cancel()
        }
    }

    private var ritualBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color.poopCream.opacity(0.72),
                    Color.poopLightGreen.opacity(0.34),
                    Color(uiColor: .systemBackground).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.92)
        }
    }

    private func ritualCard(isLarge: Bool) -> some View {
        VStack(spacing: 0) {
            switch phase {
            case .celebrate:
                CleanRitualCelebrateView(request: request, isLarge: isLarge)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            case .erase:
                CleanRitualEraseView(amount: request.amount, isLarge: isLarge) {
                    finishErase()
                }
                .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
            case .done:
                CleanRitualDoneView(
                    unlocksStompGame: request.unlocksStompGame,
                    isLarge: isLarge,
                    onFinished: onFinished
                )
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .padding(.horizontal, isLarge ? 34 : 22)
        .padding(.vertical, isLarge ? 30 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .secondarySystemGroupedBackground),
                            Color.poopCream.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.78), lineWidth: 1.5)
        }
        .shadow(color: Color.poopBrown.opacity(0.18), radius: 32, y: 22)
        .shadow(color: Color.poopAccent.opacity(0.10), radius: 18, y: -8)
    }

    private func startRitual() {
        phaseTask?.cancel()
        Haptics.success()

        phaseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2180))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                phase = .erase
            }
            Haptics.play(.light)
        }
    }

    private func finishErase() {
        withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
            phase = .done
        }
        InteractionFeedback.reward()
    }
}

private enum CleanRitualPhase {
    case celebrate
    case erase
    case done
}

private struct CleanRitualCelebrateView: View {
    let request: CleanRitualRequest
    let isLarge: Bool

    var body: some View {
        VStack(spacing: isLarge ? 22 : 18) {
            RitualEmojiBadge(text: "💩✨", isLarge: isLarge)

            VStack(spacing: 10) {
                Text("恭喜拉屎大成功！")
                    .font(.system(size: isLarge ? 42 : 33, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text("\(request.nickname) 点亮今日便便小星星，肚肚和心情都轻轻的。")
                    .font(.system(size: isLarge ? 21 : 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
            }

            HStack(spacing: 8) {
                Text(request.amount.emoji)
                Text(successPillText)
                Text("🌈")
            }
            .font(.system(size: isLarge ? 19 : 16, weight: .black, design: .rounded))
            .foregroundStyle(Color.poopAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.poopAccent.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successPillText: String {
        switch request.amount {
        case .small:
            return "小小成功也闪亮"
        case .normal:
            return "刚刚好，超棒"
        case .large:
            return "好多好多，大奖杯"
        case .none:
            return "今日打卡完成"
        }
    }
}

private struct CleanRitualEraseView: View {
    let amount: PoopAmount
    let isLarge: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: isLarge ? 18 : 14) {
            VStack(spacing: 7) {
                Text("把烦恼灰灰擦掉 ✋")
                    .font(.system(size: isLarge ? 30 : 24, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text("用小手在大便便上擦一擦")
                    .font(.system(size: isLarge ? 18 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            ErasablePoopPlayground(amount: amount, isLarge: isLarge, onComplete: onComplete)
                .frame(height: isLarge ? 360 : 292)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CleanRitualDoneView: View {
    let unlocksStompGame: Bool
    let isLarge: Bool
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: isLarge ? 22 : 18) {
            RitualEmojiBadge(text: "🌈✨", isLarge: isLarge)

            VStack(spacing: 10) {
                Text(unlocksStompGame ? "便便乐园开门啦！" : "烦恼清空啦！")
                    .font(.system(size: isLarge ? 40 : 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(unlocksStompGame ? "今天有一局 3 分钟踩便便挑战。" : "今日所有烦恼已清空，明天又是愉快的一天。")
                    .font(.system(size: isLarge ? 22 : 18, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
            }

            Button {
                InteractionFeedback.play(sound: .tap, haptic: .light)
                onFinished()
            } label: {
                Label(unlocksStompGame ? "开始今日挑战" : "好耶，完成啦", systemImage: unlocksStompGame ? "gamecontroller.fill" : "checkmark.circle.fill")
                    .font(.system(size: isLarge ? 20 : 17, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: isLarge ? 58 : 52)
                    .frame(maxWidth: .infinity)
                    .background(Color.poopAccent.gradient, in: Capsule())
                    .shadow(color: Color.poopAccent.opacity(0.24), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成清空烦恼")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErasablePoopPlayground: View {
    let amount: PoopAmount
    let isLarge: Bool
    let onComplete: () -> Void

    @State private var eraseStrokes: [[CGPoint]] = []
    @State private var coveredSampleIndexes: Set<Int> = []
    @State private var currentStrokeIndex: Int?
    @State private var coverageSize: CGSize = .zero
    @State private var silhouetteSampleCount = 0
    @State private var didComplete = false
    @State private var lastScrubFeedbackDate = Date.distantPast
    @State private var scrubFeedbackToggle = false

    private let samplesPerAxis = 30
    private let completionCoverage: CGFloat = 0.82
    private let eraseCoordinateSpace = "cleanRitualEraseSurface"

    private var rawCoverage: CGFloat {
        guard silhouetteSampleCount > 0 else { return 0 }
        return min(CGFloat(coveredSampleIndexes.count) / CGFloat(silhouetteSampleCount), 1)
    }

    private var progress: CGFloat {
        min(rawCoverage / completionCoverage, 1)
    }

    var body: some View {
        VStack(spacing: isLarge ? 13 : 10) {
            GeometryReader { proxy in
                let side = min(proxy.size.width * (isLarge ? 0.72 : 0.78), proxy.size.height * 0.96)
                let eraserRadius = max(28, side * 0.125)
                let erasePoints = eraseStrokes.flatMap { $0 }

                ZStack {
                    ZStack {
                        RitualCleanAura(progress: progress)
                            .frame(width: side * 1.08, height: side * 1.08)

                        RitualPoopCharacter(amount: amount, progress: progress)
                            .frame(width: side, height: side)
                            .mask(RitualEraseMask(strokes: eraseStrokes, radius: eraserRadius, isComplete: didComplete))
                            .shadow(color: Color.poopBrown.opacity(0.20 * (1 - progress)), radius: 16, y: 11)
                            .accessibilityHidden(true)

                        RitualScratchSparkles(points: erasePoints, progress: progress)

                        if let lastPoint = erasePoints.last, !didComplete {
                            RitualBrushCursor()
                                .position(lastPoint)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: side, height: side)
                    .coordinateSpace(name: eraseCoordinateSpace)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(eraseCoordinateSpace))
                            .onChanged { value in
                                addErasePoint(value.location, in: CGSize(width: side, height: side), eraserRadius: eraserRadius)
                            }
                            .onEnded { _ in
                                currentStrokeIndex = nil
                            }
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("擦掉大便便")
                .accessibilityHint("在便便上滑动，清空今日烦恼")
                .accessibilityAction {
                    completeIfNeeded(force: true)
                }
            }

            VStack(spacing: 7) {
                RitualProgressBar(progress: progress)

                Text(progress < 0.92 ? "擦擦擦，烦恼变小啦" : "快清空啦，亮晶晶")
                    .font(.system(size: isLarge ? 16 : 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.poopAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)
            }
        }
    }

    private func addErasePoint(_ location: CGPoint, in size: CGSize, eraserRadius: CGFloat) {
        guard !didComplete else { return }
        guard location.x >= 0, location.y >= 0, location.x <= size.width, location.y <= size.height else {
            return
        }

        prepareCoverageIfNeeded(for: size)

        let pointSpacing = max(3.5, eraserRadius * 0.20)
        let strokeIndex: Int
        let previousPoint: CGPoint?

        if let currentStrokeIndex, eraseStrokes.indices.contains(currentStrokeIndex) {
            strokeIndex = currentStrokeIndex
            previousPoint = eraseStrokes[currentStrokeIndex].last
        } else {
            eraseStrokes.append([])
            strokeIndex = eraseStrokes.count - 1
            currentStrokeIndex = strokeIndex
            previousPoint = nil
        }

        if let last = previousPoint {
            let distance = hypot(location.x - last.x, location.y - last.y)
            guard distance > pointSpacing else { return }
        }

        let newPoints = interpolatedPoints(from: previousPoint, to: location, spacing: pointSpacing)
        eraseStrokes[strokeIndex].append(contentsOf: newPoints)
        markCoverage(at: newPoints, in: size, eraserRadius: eraserRadius)
        playScrubFeedbackIfNeeded()

        completeIfNeeded()
    }

    private func prepareCoverageIfNeeded(for size: CGSize) {
        guard coverageSize != size else { return }

        coverageSize = size
        coveredSampleIndexes.removeAll()
        eraseStrokes.removeAll()
        currentStrokeIndex = nil
        silhouetteSampleCount = totalSilhouetteSamples(in: size)
    }

    private func interpolatedPoints(from previousPoint: CGPoint?, to point: CGPoint, spacing: CGFloat) -> [CGPoint] {
        guard let previousPoint else { return [point] }

        let distance = hypot(point.x - previousPoint.x, point.y - previousPoint.y)
        let steps = max(1, Int(ceil(distance / spacing)))

        return (1...steps).map { step in
            let ratio = CGFloat(step) / CGFloat(steps)
            return CGPoint(
                x: previousPoint.x + (point.x - previousPoint.x) * ratio,
                y: previousPoint.y + (point.y - previousPoint.y) * ratio
            )
        }
    }

    private func markCoverage(at points: [CGPoint], in size: CGSize, eraserRadius: CGFloat) {
        let stepX = size.width / CGFloat(samplesPerAxis)
        let stepY = size.height / CGFloat(samplesPerAxis)
        let eraserRadiusSquared = eraserRadius * eraserRadius

        for point in points {
            let minColumn = max(0, Int(floor((point.x - eraserRadius) / stepX)))
            let maxColumn = min(samplesPerAxis - 1, Int(ceil((point.x + eraserRadius) / stepX)))
            let minRow = max(0, Int(floor((point.y - eraserRadius) / stepY)))
            let maxRow = min(samplesPerAxis - 1, Int(ceil((point.y + eraserRadius) / stepY)))

            for row in minRow...maxRow {
                for column in minColumn...maxColumn {
                    let sample = CGPoint(
                        x: (CGFloat(column) + 0.5) * stepX,
                        y: (CGFloat(row) + 0.5) * stepY
                    )
                    guard isInsidePoopSilhouette(sample, in: size) else { continue }

                    let dx = point.x - sample.x
                    let dy = point.y - sample.y
                    guard dx * dx + dy * dy <= eraserRadiusSquared else { continue }

                    coveredSampleIndexes.insert(row * samplesPerAxis + column)
                }
            }
        }
    }

    private func totalSilhouetteSamples(in size: CGSize) -> Int {
        let stepX = size.width / CGFloat(samplesPerAxis)
        let stepY = size.height / CGFloat(samplesPerAxis)
        var total = 0

        for row in 0..<samplesPerAxis {
            for column in 0..<samplesPerAxis {
                let sample = CGPoint(
                    x: (CGFloat(column) + 0.5) * stepX,
                    y: (CGFloat(row) + 0.5) * stepY
                )
                if isInsidePoopSilhouette(sample, in: size) {
                    total += 1
                }
            }
        }

        return total
    }

    private func isInsidePoopSilhouette(_ point: CGPoint, in size: CGSize) -> Bool {
        let side = min(size.width, size.height)
        let centerX = size.width / 2

        return isInsideEllipse(
            point,
            center: CGPoint(x: centerX, y: side * 0.945),
            radiusX: side * 0.39,
            radiusY: side * 0.215
        ) || isInsideEllipse(
            point,
            center: CGPoint(x: centerX, y: side * 0.755),
            radiusX: side * 0.32,
            radiusY: side * 0.195
        ) || isInsideEllipse(
            point,
            center: CGPoint(x: centerX, y: side * 0.575),
            radiusX: side * 0.235,
            radiusY: side * 0.155
        ) || isInsideEllipse(
            point,
            center: CGPoint(x: centerX + side * 0.04, y: side * 0.425),
            radiusX: side * 0.095,
            radiusY: side * 0.095
        )
    }

    private func isInsideEllipse(_ point: CGPoint, center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> Bool {
        let normalizedX = (point.x - center.x) / max(radiusX, 1)
        let normalizedY = (point.y - center.y) / max(radiusY, 1)
        return normalizedX * normalizedX + normalizedY * normalizedY <= 1
    }

    private func playScrubFeedbackIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastScrubFeedbackDate) >= 0.18 else { return }

        lastScrubFeedbackDate = now
        scrubFeedbackToggle.toggle()
        SoundManager.shared.play(scrubFeedbackToggle ? .small : .tap)
        Haptics.play(.soft)
    }

    private func completeIfNeeded(force: Bool = false) {
        guard !didComplete else { return }
        guard force || rawCoverage >= completionCoverage else { return }

        didComplete = true
        if silhouetteSampleCount > 0 {
            coveredSampleIndexes = Set(0..<silhouetteSampleCount)
        }
        Haptics.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onComplete()
        }
    }
}

private struct RitualEraseMask: View {
    let strokes: [[CGPoint]]
    let radius: CGFloat
    let isComplete: Bool

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.blendMode = .destinationOut

            if isComplete {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            } else {
                for stroke in strokes {
                    draw(stroke: stroke, in: &context)
                }
            }
        }
        .compositingGroup()
    }

    private func draw(stroke: [CGPoint], in context: inout GraphicsContext) {
        guard let firstPoint = stroke.first else { return }

        if stroke.count == 1 {
            context.fill(brushCircle(at: firstPoint), with: .color(.black))
            return
        }

        var path = Path()
        path.move(to: firstPoint)

        for point in stroke.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(
            path,
            with: .color(.black),
            style: StrokeStyle(lineWidth: radius * 2, lineCap: .round, lineJoin: .round)
        )
        context.fill(brushCircle(at: firstPoint), with: .color(.black))
        if let lastPoint = stroke.last {
            context.fill(brushCircle(at: lastPoint), with: .color(.black))
        }
    }

    private func brushCircle(at point: CGPoint) -> Path {
        Path(ellipseIn: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
}

private struct RitualPoopCharacter: View {
    let amount: PoopAmount
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                RitualPoopBody()
                    .frame(width: side, height: side)

                RitualPoopHighlights()
                    .frame(width: side, height: side)
                    .opacity(0.75)

                RitualPoopFace(amount: amount)
                    .frame(width: side * 0.46, height: side * 0.25)
                    .offset(y: side * 0.12)
            }
            .scaleEffect(1 - progress * 0.08)
            .rotationEffect(.degrees(Double(sin(progress * .pi) * 2.5)))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct RitualPoopBody: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(bodyGradient)
                    .frame(width: side * 0.78, height: side * 0.43)
                    .offset(y: side * 0.16)

                Ellipse()
                    .fill(bodyGradient)
                    .frame(width: side * 0.64, height: side * 0.39)
                    .offset(y: -side * 0.05)

                Ellipse()
                    .fill(bodyGradient)
                    .frame(width: side * 0.47, height: side * 0.31)
                    .offset(y: -side * 0.27)

                Circle()
                    .fill(bodyGradient)
                    .frame(width: side * 0.19, height: side * 0.19)
                    .offset(x: side * 0.04, y: -side * 0.48)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                .poopBrownLight,
                Color(hex: "#9B642E"),
                .poopBrown
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct RitualPoopHighlights: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(width: side * 0.21, height: side * 0.055)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -side * 0.16, y: -side * 0.15)

                Capsule()
                    .fill(.white.opacity(0.13))
                    .frame(width: side * 0.16, height: side * 0.045)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -side * 0.20, y: side * 0.10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct RitualPoopFace: View {
    let amount: PoopAmount

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            VStack(spacing: width * 0.10) {
                HStack(spacing: width * 0.23) {
                    RitualPoopEye()
                    RitualPoopEye()
                }

                switch amount {
                case .small:
                    Capsule()
                        .fill(.black.opacity(0.72))
                        .frame(width: width * 0.26, height: max(4, width * 0.036))
                case .normal, .none:
                    RitualSmileShape()
                        .stroke(.black.opacity(0.74), style: StrokeStyle(lineWidth: max(4, width * 0.055), lineCap: .round))
                        .frame(width: width * 0.42, height: width * 0.20)
                case .large:
                    RitualLaughMouth()
                        .frame(width: width * 0.39, height: width * 0.24)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct RitualPoopEye: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.black.opacity(0.82))
            .frame(width: 15, height: 20)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.88))
                    .frame(width: 5, height: 5)
                    .offset(x: 3, y: 3)
            }
    }
}

private struct RitualLaughMouth: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: width * 0.24, style: .continuous)
                    .fill(.black.opacity(0.76))

                Capsule()
                    .fill(.pink.opacity(0.92))
                    .frame(width: width * 0.38, height: width * 0.17)
                    .padding(.bottom, width * 0.05)
            }
        }
    }
}

private struct RitualSmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

private struct RitualCleanAura: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.poopAccent.opacity(0.22 + progress * 0.18),
                            Color.yellow.opacity(0.16 + progress * 0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 14,
                        endRadius: 150
                    )
                )

            Circle()
                .stroke(Color.poopAccent.opacity(0.16 + progress * 0.22), lineWidth: 2)
                .scaleEffect(0.76 + progress * 0.24)
                .opacity(0.9 - progress * 0.25)
        }
    }
}

private struct RitualScratchSparkles: View {
    let points: [CGPoint]
    let progress: CGFloat

    var body: some View {
        ForEach(Array(points.suffix(12).enumerated()), id: \.offset) { index, point in
            Text(index.isMultiple(of: 3) ? "✨" : "·")
                .font(.system(size: index.isMultiple(of: 3) ? 18 : 34, weight: .black, design: .rounded))
                .foregroundStyle(index.isMultiple(of: 3) ? Color.yellow : Color.poopAccent.opacity(0.45))
                .position(point)
                .opacity((0.24 + Double(index) * 0.055) * Double(1 - min(progress, 0.82) * 0.42))
                .allowsHitTesting(false)
        }
    }
}

private struct RitualBrushCursor: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.poopAccent.opacity(0.34), lineWidth: 2)
                .background(Circle().fill(.white.opacity(0.48)))
                .frame(width: 38, height: 38)
                .shadow(color: Color.poopAccent.opacity(0.18), radius: 7, y: 3)

            ZStack {
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { index in
                        Capsule()
                            .fill(index.isMultiple(of: 2) ? Color.poopLightGreen : Color.poopAccent.opacity(0.84))
                            .frame(width: 4, height: index.isMultiple(of: 3) ? 22 : 18)
                    }
                }

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.poopAccent.gradient)
                    .frame(width: 40, height: 16)
                    .offset(y: -16)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(.white.opacity(0.58), lineWidth: 1)
                            .offset(y: -16)
                    }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#9B642E"), .poopBrown],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 10, height: 42)
                    .rotationEffect(.degrees(-38))
                    .offset(x: -14, y: -37)
                    .shadow(color: .poopBrown.opacity(0.16), radius: 4, y: 2)

                Circle()
                    .fill(Color.yellow.opacity(0.86))
                    .frame(width: 6, height: 6)
                    .offset(x: 19, y: -11)
            }
        }
        .frame(width: 74, height: 74)
        .allowsHitTesting(false)
    }
}

private struct RitualProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.poopLightGreen, .poopAccent, .yellow.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(14, proxy.size.width * progress))
                    .animation(.spring(response: 0.30, dampingFraction: 0.82), value: progress)
            }
        }
        .frame(height: 12)
        .accessibilityLabel("清空进度")
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }
}

private struct RitualEmojiBadge: View {
    let text: String
    let isLarge: Bool

    var body: some View {
        Text(text)
            .font(.system(size: isLarge ? 64 : 52))
            .frame(width: isLarge ? 132 : 108, height: isLarge ? 132 : 108)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.32),
                                Color.poopLightGreen.opacity(0.62),
                                Color.poopCream
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.82), lineWidth: 2)
            }
            .shadow(color: Color.poopAccent.opacity(0.18), radius: 18, y: 10)
    }
}

private struct RitualFloatingJoy: View {
    let isLarge: Bool

    private let symbols = ["✨", "🌟", "🫧", "💛", "🌈", "✨", "🧼", "⭐️"]
    private let positions: [CGPoint] = [
        CGPoint(x: 0.14, y: 0.18),
        CGPoint(x: 0.80, y: 0.14),
        CGPoint(x: 0.92, y: 0.34),
        CGPoint(x: 0.10, y: 0.43),
        CGPoint(x: 0.82, y: 0.72),
        CGPoint(x: 0.20, y: 0.78),
        CGPoint(x: 0.50, y: 0.10),
        CGPoint(x: 0.55, y: 0.88)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(symbols.indices, id: \.self) { index in
                Text(symbols[index])
                    .font(.system(size: isLarge ? 34 : 25))
                    .rotationEffect(.degrees(Double(index * 17 - 34)))
                    .opacity(index.isMultiple(of: 2) ? 0.78 : 0.56)
                    .position(
                        x: proxy.size.width * positions[index].x,
                        y: proxy.size.height * positions[index].y
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}
