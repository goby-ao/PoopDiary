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

struct CheckInRewardOverlay: View {
    let reward: CheckInRewardPresentation
    let onDismiss: () -> Void

    var body: some View {
        if reward.usesFullCelebration {
            FullCheckInRewardOverlay(reward: reward, onDismiss: onDismiss)
        } else if let personalRecord = reward.personalRecord {
            PersonalRecordToastOverlay(record: personalRecord, onDismiss: onDismiss)
        }
    }
}

private struct PersonalRecordToastOverlay: View {
    let record: PersonalRecordEvent
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var didDismiss = false

    var body: some View {
        VStack {
            Button(action: dismiss) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.poopAccent.gradient)
                            .frame(width: 58, height: 58)

                        Image(systemName: "medal.fill")
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("新纪录！")
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .foregroundStyle(Color.poopAccent)

                        Text("连续拉粑粑 \(record.newValue) 天")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .foregroundStyle(.primary)

                        Text("超过此前的 \(record.previousValue) 天")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.poopAccent.opacity(0.72))
                }
                .padding(16)
                .frame(maxWidth: 370)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.poopAccent.opacity(0.38), lineWidth: 1.5)
                }
                .shadow(color: Color.poopAccent.opacity(0.2), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新纪录，连续拉粑粑 \(record.newValue) 天，超过此前的 \(record.previousValue) 天，点按收下纪录牌")
            .offset(y: isVisible ? 0 : -24)
            .opacity(isVisible ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            InteractionFeedback.play(sound: .achievement, haptic: .medium)
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) {
                isVisible = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func dismiss() {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss()
    }
}

private struct FullCheckInRewardOverlay: View {
    let reward: CheckInRewardPresentation
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var celebrationTrigger = UUID()

    private var title: String {
        if reward.personalRecord != nil, !reward.achievements.isEmpty {
            return "双喜临门！"
        }
        return reward.personalRecord == nil ? "新勋章解锁！" : "新纪录！"
    }

    private var buttonTitle: String {
        if reward.personalRecord != nil, !reward.achievements.isEmpty {
            return "收下奖励"
        }
        return reward.personalRecord == nil ? "收下勋章" : "收下纪录牌"
    }

    private var accessibilityText: String {
        var parts = [title]
        if let record = reward.personalRecord {
            parts.append("连续拉粑粑 \(record.newValue) 天，超过此前的 \(record.previousValue) 天")
        }
        if !reward.achievements.isEmpty {
            parts.append("解锁勋章 " + reward.achievements.map(\.title).joined(separator: "、"))
        }
        return parts.joined(separator: "，")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            CelebrationOverlay(effect: .confetti, trigger: celebrationTrigger)
                .frame(width: 360, height: 420)
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                rewardSeal
                    .scaleEffect(isVisible ? 1 : 0.4)

                VStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 30, weight: .black, design: .rounded))

                    if let record = reward.personalRecord {
                        Text("连续拉粑粑 \(record.newValue) 天")
                            .font(.system(.title2, design: .rounded).weight(.black))
                            .foregroundStyle(Color.poopAccent)

                        Text("超过此前的 \(record.previousValue) 天")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)

                if !reward.achievements.isEmpty {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(reward.personalRecord == nil ? "本次解锁" : "同时解锁")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)

                            ForEach(reward.achievements) { achievement in
                                HStack(spacing: 10) {
                                    Image(systemName: achievement.systemImage)
                                        .font(.system(size: 17, weight: .black))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(Color.poopAccent, in: Circle())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(achievement.title)
                                            .font(.system(.subheadline, design: .rounded).weight(.black))
                                        Text(achievement.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: 170)
                    .padding(12)
                    .background(Color.poopPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button(action: onDismiss) {
                    Text(buttonTitle)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.poopAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 350)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.poopAccent.opacity(0.28), lineWidth: 1.5)
            }
            .padding(20)
            .scaleEffect(isVisible ? 1 : 0.92)
            .opacity(isVisible ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityText)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .onAppear {
            InteractionFeedback.play(sound: .achievement, haptic: .heavy)
            celebrationTrigger = UUID()
            withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.66)) {
                isVisible = true
            }
        }
    }

    @ViewBuilder
    private var rewardSeal: some View {
        ZStack {
            Circle()
                .fill(Color.poopAccent.gradient)
                .frame(width: 112, height: 112)
                .shadow(color: Color.poopAccent.opacity(0.34), radius: 22, y: 10)

            if let record = reward.personalRecord {
                VStack(spacing: -2) {
                    Text("\(record.newValue)")
                        .font(.system(size: 48, weight: .black, design: .rounded).monospacedDigit())
                    Text("天")
                        .font(.system(.caption, design: .rounded).weight(.black))
                }
                .foregroundStyle(.white)
            } else {
                Image(systemName: reward.achievements.count == 1 ? reward.achievements[0].systemImage : "sparkles")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(.white)
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

#Preview("Personal Record Toast") {
    Color.poopCream
        .ignoresSafeArea()
        .overlay {
            CheckInRewardOverlay(
                reward: CheckInRewardPresentation(
                    profileID: ProfileStore.defaultProfileID,
                    dayKey: "2026-07-18",
                    personalRecord: PersonalRecordEvent(
                        kind: .longestPoopStreak,
                        profileID: ProfileStore.defaultProfileID,
                        dayKey: "2026-07-18",
                        previousValue: 12,
                        newValue: 13
                    ),
                    achievements: []
                ),
                onDismiss: {}
            )
        }
}

#Preview("Combined Reward") {
    CheckInRewardOverlay(
        reward: CheckInRewardPresentation(
            profileID: ProfileStore.defaultProfileID,
            dayKey: "2026-07-18",
            personalRecord: PersonalRecordEvent(
                kind: .longestPoopStreak,
                profileID: ProfileStore.defaultProfileID,
                dayKey: "2026-07-18",
                previousValue: 13,
                newValue: 14
            ),
            achievements: [
                AchievementProgress(
                    id: .streak7,
                    title: "黄金一周",
                    subtitle: "连续打卡 7 天",
                    systemImage: "crown.fill",
                    progress: 7,
                    target: 7
                )
            ]
        ),
        onDismiss: {}
    )
}
