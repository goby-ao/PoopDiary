import SwiftUI

struct CelebrationOverlay: View {
    let effect: PoopFeedbackEffect
    let trigger: UUID

    @State private var animate = false

    private var pieces: [CelebrationPiece] {
        let count: Int
        switch effect {
        case .idle:
            count = 0
        case .droplets:
            count = 12
        case .confetti:
            count = 22
        case .fireworks:
            count = 34
        }

        return (0..<count).map { index in
            CelebrationPiece(index: index, effect: effect)
        }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                piece.shape
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .rotationEffect(.degrees(animate ? piece.rotation : 0))
                    .offset(x: piece.xOffset, y: animate ? piece.endYOffset : piece.startYOffset)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: piece.duration).delay(piece.delay),
                        value: animate
                    )
            }

            if effect == .fireworks {
                Text("🏆")
                    .font(.system(size: 48))
                    .scaleEffect(animate ? 1.2 : 0.6)
                    .opacity(animate ? 0 : 1)
                    .animation(.spring(response: 0.45, dampingFraction: 0.55), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: run)
        .onChange(of: trigger) { _, _ in
            run()
        }
    }

    private func run() {
        animate = false
        DispatchQueue.main.async {
            animate = true
        }
    }
}

private struct CelebrationPiece: Identifiable {
    let id: Int
    let effect: PoopFeedbackEffect

    init(index: Int, effect: PoopFeedbackEffect) {
        self.id = index
        self.effect = effect
    }

    var shape: AnyShape {
        switch effect {
        case .droplets:
            AnyShape(Circle())
        case .confetti, .fireworks, .idle:
            id.isMultiple(of: 3) ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    var color: Color {
        switch effect {
        case .idle:
            return .clear
        case .droplets:
            return [.cyan, .blue.opacity(0.7), .poopLightGreen][id % 3]
        case .confetti:
            return [.yellow, .pink, .poopAccent, .orange, .mint][id % 5]
        case .fireworks:
            return [.yellow, .orange, .red, .poopDeepGreen, .purple][id % 5]
        }
    }

    var size: CGFloat {
        switch effect {
        case .droplets:
            return CGFloat(8 + (id % 3) * 3)
        case .fireworks:
            return CGFloat(8 + (id % 5) * 2)
        default:
            return CGFloat(7 + (id % 4) * 3)
        }
    }

    var xOffset: CGFloat {
        let lane = CGFloat((id % 11) - 5)
        return lane * 22
    }

    var startYOffset: CGFloat {
        switch effect {
        case .droplets:
            return -12
        default:
            return -36
        }
    }

    var endYOffset: CGFloat {
        switch effect {
        case .droplets:
            return CGFloat(44 + (id % 4) * 14)
        case .fireworks:
            return CGFloat(-70 + (id % 9) * 20)
        default:
            return CGFloat(86 + (id % 5) * 16)
        }
    }

    var rotation: Double {
        Double((id % 8) * 45)
    }

    var delay: Double {
        Double(id % 7) * 0.035
    }

    var duration: Double {
        switch effect {
        case .fireworks:
            return 1.15
        default:
            return 0.95
        }
    }
}

#Preview {
    CelebrationOverlay(effect: .confetti, trigger: UUID())
        .frame(width: 280, height: 220)
        .background(Color.poopCream)
}
