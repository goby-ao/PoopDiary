import SwiftUI

struct AchievementWallView: View {
    let records: [PoopRecord]
    let profileID: String

    private var achievements: [AchievementProgress] {
        AchievementManager.progressList(records: records, profileID: profileID)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 134), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("勋章墙", systemImage: "medal.fill")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text("\(achievements.filter(\.isUnlocked).count)/\(achievements.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(achievements) { achievement in
                    AchievementBadgeView(achievement: achievement)
                }
            }
        }
    }
}

struct AchievementBadgeView: View {
    let achievement: AchievementProgress

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.poopAccent.opacity(0.95) : Color.gray.opacity(0.18))
                    .frame(width: 54, height: 54)

                Image(systemName: achievement.systemImage)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(achievement.isUnlocked ? .white : .secondary)
            }

            Text(achievement.title)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(achievement.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(minHeight: 28)

            ProgressView(value: Double(min(achievement.progress, achievement.target)), total: Double(achievement.target))
                .tint(achievement.isUnlocked ? .poopAccent : .gray)

            Text(achievement.isUnlocked ? "已解锁" : achievement.progressText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(achievement.isUnlocked ? Color.poopAccent : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(achievement.isUnlocked ? Color.poopPrimary.opacity(0.16) : Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(achievement.isUnlocked ? Color.poopAccent.opacity(0.38) : Color.gray.opacity(0.12), lineWidth: 1.5)
        }
        .saturation(achievement.isUnlocked ? 1 : 0)
    }
}

struct AchievementUnlockOverlay: View {
    let achievement: AchievementProgress
    let onDismiss: () -> Void
    @State private var isVisible = false
    @State private var celebrationTrigger = UUID()

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                CelebrationOverlay(effect: .confetti, trigger: celebrationTrigger)
                    .frame(width: 260, height: 160)
                    .allowsHitTesting(false)

                ZStack {
                    Circle()
                        .fill(Color.poopAccent.gradient)
                        .frame(width: 116, height: 116)
                        .shadow(color: Color.poopAccent.opacity(0.36), radius: 24, y: 12)

                    Image(systemName: achievement.systemImage)
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isVisible ? 1 : 0.35)

                VStack(spacing: 8) {
                    Text("新勋章解锁！")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(achievement.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(achievement.subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("收下勋章")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.poopAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .onAppear {
            InteractionFeedback.play(sound: .achievement, haptic: .heavy)
            celebrationTrigger = UUID()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                isVisible = true
            }
        }
    }
}

#Preview("Achievement Wall") {
    AchievementWallView(
        records: [
            PoopRecord(date: .now, didPoop: true, amount: .large),
            PoopRecord(date: Calendar.poopDiary.addingDays(-1, to: .now), didPoop: true, amount: .normal)
        ],
        profileID: ProfileStore.defaultProfileID
    )
    .padding()
}
