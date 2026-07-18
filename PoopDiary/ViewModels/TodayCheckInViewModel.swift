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
    private(set) var activeReward: CheckInRewardPresentation?
    private var rewardQueue: [CheckInRewardPresentation] = []
    private var mascotTapDates: [Date] = []

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

    @discardableResult
    func resetTodayRecord(profileID: String, in context: ModelContext) -> Bool {
        do {
            try PoopRecordStore.deleteRecord(on: .now, profileID: profileID, in: context)
            CheckInRewardStore.clear(
                profileID: profileID,
                dayKey: Calendar.poopDiary.dayKey(for: .now)
            )
            clearRewards()
            resetSelection()
            SoundManager.shared.play(.tap)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "重置失败，请再试一次"
            return false
        }
    }

    func loadToday(profileID: String, in context: ModelContext, preserveDraft: Bool = true) {
        do {
            if let record = try PoopRecordStore.record(on: .now, profileID: profileID, in: context) {
                apply(record: record, shouldTriggerReward: false)
            } else if preserveDraft && hasPreselection {
                // Tab 切回首页会触发 onAppear；如果孩子已经做了预选但还没长按确认，
                // 不要因为本地暂时还没有记录就把预选清掉。
            } else {
                didPoop = nil
                amount = .none
                message = "今天拉粑粑了吗？"
                mood = .idle
                effect = .idle
            }

            restorePendingRewards(profileID: profileID, in: context)
        } catch {
            errorMessage = "读取今日记录失败"
        }
    }

    @discardableResult
    func confirmSelection(
        profileID: String,
        in context: ModelContext,
        playFeedback: Bool = true
    ) -> PoopRecord? {
        guard let didPoop else {
            errorMessage = "请先选今天的量"
            Haptics.play(.soft)
            return nil
        }

        guard !didPoop || amount != .none else {
            errorMessage = "请先选今天的量"
            Haptics.play(.soft)
            return nil
        }

        let normalizedAmount: PoopAmount = didPoop ? (amount == .none ? .normal : amount) : .none
        return save(
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
        let achievements = unlockAchievements(profileID: profileID, in: context, isComboTap: true)
        enqueueReward(
            profileID: profileID,
            dayKey: Calendar.poopDiary.dayKey(for: now),
            personalRecord: nil,
            achievements: achievements
        )

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            if mood == .goofy {
                mood = baseMood()
                effect = .idle
                message = currentMessage()
            }
        }
    }

    @discardableResult
    private func save(
        didPoop: Bool,
        amount: PoopAmount,
        sound: SoundEffect,
        haptic: HapticEffect,
        profileID: String,
        playFeedback: Bool = true,
        in context: ModelContext
    ) -> PoopRecord? {
        let saveDate = Date.now
        let recordsBeforeSave = try? PoopRecordStore.fetchRecords(profileID: profileID, in: context)
        let todayKey = Calendar.poopDiary.dayKey(for: saveDate)
        let shouldEvaluateRewards = recordsBeforeSave?.contains { $0.dayKey == todayKey } == false
        let previousBest = recordsBeforeSave.map(PoopStreakCalculator.longest(records:))

        do {
            let record = try PoopRecordStore.upsert(
                date: saveDate,
                profileID: profileID,
                didPoop: didPoop,
                amount: amount,
                in: context
            )
            apply(record: record, shouldTriggerReward: true)
            if playFeedback {
                InteractionFeedback.play(sound: sound, haptic: haptic)
            }

            if shouldEvaluateRewards {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    InteractionFeedback.reward()
                }
            }

            let achievements = unlockAchievements(profileID: profileID, in: context)
            var personalRecord: PersonalRecordEvent?

            if shouldEvaluateRewards,
               let previousBest,
               let recordsAfterSave = try? PoopRecordStore.fetchRecords(profileID: profileID, in: context) {
                personalRecord = PersonalRecordManager.makeEvent(
                    profileID: profileID,
                    dayKey: record.dayKey,
                    didPoop: record.didPoop,
                    previousBest: previousBest,
                    recordsAfterSave: recordsAfterSave
                )
            }

            enqueueReward(
                profileID: profileID,
                dayKey: record.dayKey,
                personalRecord: personalRecord,
                achievements: achievements
            )

            errorMessage = nil
            return record
        } catch {
            errorMessage = "保存失败，请再点一次"
            return nil
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

    @discardableResult
    func presentNextRewardIfAvailable() -> Bool {
        guard activeReward == nil, !rewardQueue.isEmpty else { return false }
        activeReward = rewardQueue.removeFirst()
        return true
    }

    func completeReward(_ reward: CheckInRewardPresentation) {
        guard activeReward?.id == reward.id else { return }
        activeReward = nil
        CheckInRewardStore.remove(reward)
    }

    func clearRewards() {
        activeReward = nil
        rewardQueue.removeAll()
    }

    private func restorePendingRewards(profileID: String, in context: ModelContext) {
        guard let records = try? PoopRecordStore.fetchRecords(profileID: profileID, in: context) else { return }
        let dayKey = Calendar.poopDiary.dayKey(for: .now)

        for reward in CheckInRewardStore.pendingRewards(profileID: profileID, dayKey: dayKey) {
            if let event = reward.personalRecord,
               !PersonalRecordManager.isValid(
                event,
                profileID: profileID,
                dayKey: dayKey,
                records: records
               ) {
                CheckInRewardStore.remove(reward)
                continue
            }

            enqueueReward(reward, shouldPersist: false)
        }
    }

    private func enqueueReward(
        profileID: String,
        dayKey: String,
        personalRecord: PersonalRecordEvent?,
        achievements: [AchievementProgress]
    ) {
        guard personalRecord != nil || !achievements.isEmpty else { return }

        let reward = CheckInRewardPresentation(
            profileID: profileID,
            dayKey: dayKey,
            personalRecord: personalRecord,
            achievements: achievements
        )
        enqueueReward(reward, shouldPersist: true)
    }

    private func enqueueReward(_ reward: CheckInRewardPresentation, shouldPersist: Bool) {
        let alreadyQueued = activeReward?.id == reward.id || rewardQueue.contains { queued in
            queued.id == reward.id
                || (reward.personalRecord != nil && queued.personalRecord?.id == reward.personalRecord?.id)
        }
        guard !alreadyQueued else { return }

        if shouldPersist, !CheckInRewardStore.append(reward) {
            return
        }
        confirmRewardSources(reward)
        rewardQueue.append(reward)
        if !reward.achievements.isEmpty || reward.personalRecord?.isMajorMilestone == true {
            effect = .confetti
            rewardTrigger = UUID()
        }
    }

    private func confirmRewardSources(_ reward: CheckInRewardPresentation) {
        AchievementManager.markUnlocked(reward.achievements, profileID: reward.profileID)
        if let personalRecord = reward.personalRecord {
            PersonalRecordManager.markTriggered(personalRecord)
        }
    }

    private func unlockAchievements(
        profileID: String,
        in context: ModelContext,
        isComboTap: Bool = false
    ) -> [AchievementProgress] {
        do {
            let unlocked: [AchievementProgress]
            if isComboTap {
                unlocked = try AchievementManager.newlyUnlockableAfterComboTap(profileID: profileID, in: context)
            } else {
                unlocked = try AchievementManager.newlyUnlockable(profileID: profileID, in: context)
            }

            if !unlocked.isEmpty {
                effect = .confetti
                rewardTrigger = UUID()
            }
            return unlocked
        } catch {
            // 成就失败不影响打卡主流程，只静默跳过。
            return []
        }
    }
}
