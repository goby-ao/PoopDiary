import SwiftUI

struct SleepyPoopMark: View {
    let maxSize: CGFloat

    private var size: CGFloat {
        maxSize * 0.54
    }

    var body: some View {
        ZStack {
            sleepyBody
            sleepyFace
                .offset(y: size * 0.08)

            SleepyZTrail(size: size)
                .offset(x: size * 0.60, y: -size * 0.58)
        }
        .frame(width: maxSize, height: maxSize)
        .opacity(0.9)
        .accessibilityHidden(true)
    }

    private var sleepyBody: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(sleepyGradient)
                .frame(width: size * 0.88, height: size * 0.42)
                .offset(y: size * 0.12)

            Ellipse()
                .fill(sleepyGradient)
                .frame(width: size * 0.68, height: size * 0.38)
                .offset(y: -size * 0.08)

            Ellipse()
                .fill(sleepyGradient)
                .frame(width: size * 0.48, height: size * 0.32)
                .offset(y: -size * 0.26)

            Circle()
                .fill(sleepyGradient)
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: size * 0.04, y: -size * 0.42)
        }
    }

    private var sleepyGradient: LinearGradient {
        LinearGradient(
            colors: [.poopBrownLight.opacity(0.58), .poopBrown.opacity(0.46)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sleepyFace: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.18) {
                Capsule()
                    .fill(.black.opacity(0.44))
                    .frame(width: size * 0.13, height: max(1.5, size * 0.035))
                Capsule()
                    .fill(.black.opacity(0.44))
                    .frame(width: size * 0.13, height: max(1.5, size * 0.035))
            }

            Capsule()
                .fill(.black.opacity(0.4))
                .frame(width: size * 0.20, height: max(1.5, size * 0.035))
        }
    }
}

private struct SleepyZTrail: View {
    let size: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: size * 0.02) {
            ForEach(0..<3, id: \.self) { index in
                Text("Z")
                    .font(.system(size: zSize(for: index), weight: .black, design: .rounded))
                    .foregroundStyle(Color.poopBrown.opacity(0.52 + Double(index) * 0.08))
                    .offset(y: -CGFloat(index) * size * 0.08)
            }
        }
        .rotationEffect(.degrees(-18))
    }

    private func zSize(for index: Int) -> CGFloat {
        size * (0.20 + CGFloat(index) * 0.08)
    }
}
