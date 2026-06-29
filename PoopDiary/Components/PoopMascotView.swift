import SwiftUI

struct PoopMascotView: View {
    let mood: MascotMood
    let bounceTrigger: UUID
    let onTap: () -> Void

    @State private var isBreathing = false
    @State private var isBlinking = false
    @State private var isBouncing = false

    init(mood: MascotMood, bounceTrigger: UUID, onTap: @escaping () -> Void = {}) {
        self.mood = mood
        self.bounceTrigger = bounceTrigger
        self.onTap = onTap
    }

    var body: some View {
        ZStack {
            mascotBody
            face
                .offset(y: 20)

            if mood == .sleepy {
                sleepyBlanket
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                Text("Zzz")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.poopAccent)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 64, y: -72)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 220, height: 220)
        .scaleEffect((isBreathing ? 1.02 : 0.98) * (isBouncing ? 1.12 : 1.0))
        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: isBreathing)
        .animation(.spring(response: 0.32, dampingFraction: 0.45), value: isBouncing)
        .rotationEffect(.degrees(mood == .goofy && isBouncing ? -5 : 0))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            isBreathing = true
        }
        .onChange(of: bounceTrigger) { _, _ in
            performBounce()
        }
        .task {
            await blinkLoop()
        }
        .accessibilityLabel(accessibilityText)
    }

    private var mascotBody: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(bodyGradient)
                .frame(width: 164, height: 100)
                .offset(y: 42)

            Ellipse()
                .fill(bodyGradient)
                .frame(width: 132, height: 88)
                .offset(y: -4)

            Ellipse()
                .fill(bodyGradient)
                .frame(width: 96, height: 68)
                .offset(y: -48)

            Circle()
                .fill(bodyGradient)
                .frame(width: 46, height: 46)
                .offset(x: 8, y: -86)
        }
        .shadow(color: .poopBrown.opacity(0.22), radius: 18, y: 12)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [.poopBrownLight, .poopBrown],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var face: some View {
        VStack(spacing: 14) {
            if mood == .goofy {
                HStack(spacing: 34) {
                    XEye()
                    eye
                }
            } else {
                HStack(spacing: 38) {
                    eye
                    eye
                }
            }

            mouth
        }
    }

    private var eye: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.black.opacity(0.82))
            .frame(width: 15, height: (isBlinking || mood == .sleepy) ? 4 : 18)
            .overlay(alignment: .topLeading) {
                if !isBlinking && mood != .sleepy {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 5, height: 5)
                        .offset(x: 3, y: 3)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isBlinking)
            .animation(.easeInOut(duration: 0.18), value: mood)
    }

    private var mouth: some View {
        Group {
            switch mood {
            case .sleepy:
                Capsule()
                    .stroke(.black.opacity(0.7), lineWidth: 4)
                    .frame(width: 24, height: 8)
            case .goofy:
                VStack(spacing: -2) {
                    ArcSmile()
                        .stroke(.black.opacity(0.72), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 48, height: 24)

                    Capsule()
                        .fill(.pink.opacity(0.86))
                        .frame(width: 16, height: 20)
                        .offset(x: 10)
                }
            case .idle, .happy:
                ArcSmile()
                    .stroke(.black.opacity(0.72), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 44, height: 26)
            }
        }
    }

    private var sleepyBlanket: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.mint.opacity(0.92), .poopPrimary.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 188, height: 86)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.45))
                    .frame(width: 150, height: 12)
                    .padding(.top, 10)
            }
            .offset(y: 58)
            .shadow(color: .poopAccent.opacity(0.18), radius: 12, y: 8)
    }

    private var accessibilityText: String {
        switch mood {
        case .idle, .happy:
            return "开心的便便吉祥物"
        case .sleepy:
            return "睡觉的便便吉祥物"
        case .goofy:
            return "搞怪的便便吉祥物"
        }
    }

    private func performBounce() {
        isBouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isBouncing = false
        }
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.8))
            await MainActor.run {
                isBlinking = true
            }
            try? await Task.sleep(for: .milliseconds(130))
            await MainActor.run {
                isBlinking = false
            }
        }
    }
}

private struct XEye: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.78))
                .frame(width: 22, height: 5)
                .rotationEffect(.degrees(45))

            Capsule()
                .fill(.black.opacity(0.78))
                .frame(width: 22, height: 5)
                .rotationEffect(.degrees(-45))
        }
        .frame(width: 22, height: 22)
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(24),
            endAngle: .degrees(156),
            clockwise: false
        )
        return path
    }
}

#Preview("Happy") {
    PoopMascotView(mood: .happy, bounceTrigger: UUID())
        .padding()
        .background(Color.poopCream)
}

#Preview("Sleepy") {
    PoopMascotView(mood: .sleepy, bounceTrigger: UUID())
        .padding()
        .background(Color.poopCream)
}
