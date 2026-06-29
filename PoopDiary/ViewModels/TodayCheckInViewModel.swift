import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TodayCheckInViewModel {
    var didPoop: Bool?
    var amount: PoopAmount = .none
    var message = "今天拉粑粑了吗？"
    var mood: MascotMood = .idle
    var effect: PoopFeedbackEffect = .idle
    var rewardTrigger = UUID()
    var errorMessage: String?
    var unlockedAchievement: AchievementProgress?
    private var mascotTapDates: [Date] = []

    var hasCompletedToday: Bool {
        didPoop != nil
    }

    var hasPreselection: Bool {
        guard let didPoop else { return false }
        return !didPoop || amount != .none
    }

    func preparePoopSelection() {
        didPoop = true
        mood = .happy
        message = "选一选今天的量"
        effect = .idle
        InteractionFeedback.play(sound: .poop, haptic: .light)
    }

    func selectAmount(_ nextAmount: PoopAmount) {
        guard nextAmount != .none else { return }
        didPoop = true
        amount = nextAmount
        mood = .happy
        message = previewMessage(didPoop: true, amount: nextAmount)
        effect = feedbackEffect(didPoop: true, amount: nextAmount)
        rewardTrigger = UUID()
        InteractionFeedback.play(sound: sound(for: nextAmount), haptic: .light)
    }

    func preselectNoPoop() {
        didPoop = false
        amount = .none
        mood = .sleepy
        message = previewMessage(didPoop: false, amount: .none)
        effect = .idle
        rewardTrigger = UUID()
        InteractionFeedback.play(sound: .sleep, haptic: .light)
    }

    func resetSelection() {
        didPoop = nil
        amount = .none
        message = "今天拉粑粑了吗？"
        mood = .idle
        effect = .idle
        rewardTrigger = UUID()
        Haptics.play(.soft)
    }

    func resetTodayRecord(profileID: String, in context: ModelContext) {
        do {
            try PoopRecordStore.deleteRecord(on: .now, profileID: profileID, in: context)
            resetSelection()
            SoundManager.shared.play(.tap)
            errorMessage = nil
        } catch {
            errorMessage = "重置失败，请再试一次"
        }
    }

    func loadToday(profileID: String, in context: ModelContext) {
        do {
            if let record = try PoopRecordStore.record(on: .now, profileID: profileID, in: context) {
                apply(record: record, shouldTriggerReward: false)
            } else {
                didPoop = nil
                amount = .none
                message = "今天拉粑粑了吗？"
                mood = .idle
                effect = .idle
            }
        } catch {
            errorMessage = "读取今日记录失败"
        }
    }

    func confirmSelection(
        profileID: String,
        in context: ModelContext,
        playFeedback: Bool = true
    ) {
        guard let didPoop else {
            errorMessage = "请先选今天的量"
            Haptics.play(.soft)
            return
        }

        guard !didPoop || amount != .none else {
            errorMessage = "请先选今天的量"
            Haptics.play(.soft)
            return
        }

        let normalizedAmount: PoopAmount = didPoop ? (amount == .none ? .normal : amount) : .none
        save(
            didPoop: didPoop,
            amount: normalizedAmount,
            sound: .flush,
            haptic: .success,
            profileID: profileID,
            playFeedback: playFeedback,
            in: context
        )
    }

    func tapMascot(profileID: String, in context: ModelContext) {
        let now = Date()
        mascotTapDates = mascotTapDates.filter { now.timeIntervalSince($0) < 1.1 }
        mascotTapDates.append(now)

        guard mascotTapDates.count >= 5 else {
            InteractionFeedback.play(sound: .tap, haptic: .light)
            rewardTrigger = UUID()
            return
        }

        mascotTapDates.removeAll()
        message = "噗噗连击！"
        mood = .goofy
        effect = .confetti
        rewardTrigger = UUID()
        InteractionFeedback.mascotCombo()
        unlockAchievements(profileID: profileID, in: context, isComboTap: true)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            if mood == .goofy {
                mood = baseMood()
                effect = .idle
                message = currentMessage()
            }
        }
    }

    private func save(
        didPoop: Bool,
        amount: PoopAmount,
        sound: SoundEffect,
        haptic: HapticEffect,
        profileID: String,
        playFeedback: Bool = true,
        in context: ModelContext
    ) {
        let shouldPlayReward = !hasCompletedToday

        do {
            let record = try PoopRecordStore.upsert(
                profileID: profileID,
                didPoop: didPoop,
                amount: amount,
                in: context
            )
            apply(record: record, shouldTriggerReward: true)
            if playFeedback {
                InteractionFeedback.play(sound: sound, haptic: haptic)
            }

            if shouldPlayReward {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    InteractionFeedback.reward()
                }
            }

            unlockAchievements(profileID: profileID, in: context)

            errorMessage = nil
        } catch {
            errorMessage = "保存失败，请再点一次"
        }
    }

    private func apply(record: PoopRecord, shouldTriggerReward: Bool) {
        didPoop = record.didPoop
        amount = record.amount
        mood = record.didPoop ? .happy : .sleepy
        message = feedbackMessage(for: record)
        effect = feedbackEffect(for: record)

        if shouldTriggerReward {
            rewardTrigger = UUID()
        }
    }

    private func feedbackMessage(for record: PoopRecord) -> String {
        feedbackMessage(didPoop: record.didPoop, amount: record.amount)
    }

    private func feedbackMessage(didPoop: Bool, amount: PoopAmount) -> String {
        guard didPoop else {
            return "今天小肚肚休息一下，也很棒～"
        }

        switch amount {
        case .none:
            return "记录好啦，给你一颗小星星"
        case .small:
            return "少量也棒～"
        case .normal:
            return "哇，节奏刚刚好，撒花"
        case .large:
            return "超厉害！大奖杯亮起来"
        }
    }

    private func feedbackEffect(for record: PoopRecord) -> PoopFeedbackEffect {
        feedbackEffect(didPoop: record.didPoop, amount: record.amount)
    }

    private func feedbackEffect(didPoop: Bool, amount: PoopAmount) -> PoopFeedbackEffect {
        guard didPoop else { return .idle }

        switch amount {
        case .none:
            return .idle
        case .small:
            return .droplets
        case .normal:
            return .confetti
        case .large:
            return .fireworks
        }
    }

    private func previewMessage(didPoop: Bool, amount: PoopAmount) -> String {
        guard didPoop else {
            return "小肚肚休息，长按冲水确认"
        }

        switch amount {
        case .none:
            return "选一选今天的量"
        case .small:
            return "少量已选，长按确认"
        case .normal:
            return "正常已选，准备冲水"
        case .large:
            return "很多已选，大奖杯预备"
        }
    }

    private func sound(for amount: PoopAmount) -> SoundEffect {
        switch amount {
        case .none:
            return .tap
        case .small:
            return .small
        case .normal:
            return .normal
        case .large:
            return .large
        }
    }

    private func haptic(for amount: PoopAmount) -> HapticEffect {
        switch amount {
        case .none:
            return .light
        case .small:
            return .light
        case .normal:
            return .success
        case .large:
            return .heavy
        }
    }

    private func baseMood() -> MascotMood {
        if didPoop == true { return .happy }
        if didPoop == false { return .sleepy }
        return .idle
    }

    private func currentMessage() -> String {
        guard let didPoop else { return "今天拉粑粑了吗？" }
        return feedbackMessage(didPoop: didPoop, amount: amount)
    }

    private func unlockAchievements(profileID: String, in context: ModelContext, isComboTap: Bool = false) {
        do {
            let unlocked: [AchievementProgress]
            if isComboTap {
                unlocked = try AchievementManager.markComboTap(profileID: profileID, in: context)
            } else {
                unlocked = try AchievementManager.newlyUnlocked(profileID: profileID, in: context)
            }

            if let achievement = unlocked.first {
                unlockedAchievement = achievement
                effect = .confetti
                rewardTrigger = UUID()
            }
        } catch {
            // 成就失败不影响打卡主流程，只静默跳过。
        }
    }
}
