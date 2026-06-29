import Foundation
import SwiftData

enum AchievementID: String, CaseIterable, Codable, Identifiable {
    case streak3
    case streak7
    case streak30
    case count10
    case count100
    case count365
    case normal7
    case largeDay
    case earlyCheckIn
    case comboTap

    var id: String { rawValue }
}

struct AchievementProgress: Identifiable, Hashable {
    let id: AchievementID
    let title: String
    let subtitle: String
    let systemImage: String
    let progress: Int
    let target: Int

    var isUnlocked: Bool {
        progress >= target
    }

    var progressText: String {
        "\(min(progress, target))/\(target)"
    }
}

enum AchievementManager {
    static func progressList(records: [PoopRecord], profileID: String) -> [AchievementProgress] {
        let profileRecords = records.filter { $0.profileID == profileID }
        let totalPoopCount = profileRecords.filter(\.didPoop).count
        let currentStreak = streak(records: profileRecords) { _ in true }
        let normalStreak = streak(records: profileRecords) { $0.didPoop && $0.amount == .normal }
        let hasLargeDay = profileRecords.contains { $0.didPoop && $0.amount == .large }
        let hasEarlyCheckIn = profileRecords.contains { record in
            record.didPoop && Calendar.poopDiary.component(.hour, from: record.createdAt) < 8
        }
        let hasComboTap = UserDefaults.standard.bool(forKey: comboTapKey(profileID: profileID))

        return [
            item(.streak3, "小小三连", "连续打卡 3 天", "flame.fill", currentStreak, 3),
            item(.streak7, "黄金一周", "连续打卡 7 天", "crown.fill", currentStreak, 7),
            item(.streak30, "月亮队长", "连续打卡 30 天", "moon.stars.fill", currentStreak, 30),
            item(.count10, "十次闪闪", "累计拉了 10 次", "star.circle.fill", totalPoopCount, 10),
            item(.count100, "百次勇士", "累计拉了 100 次", "medal.fill", totalPoopCount, 100),
            item(.count365, "全年守护者", "累计拉了 365 次", "rosette", totalPoopCount, 365),
            item(.normal7, "规律小达人", "连续 7 天正常", "checkmark.seal.fill", normalStreak, 7),
            item(.largeDay, "大份惊喜", "记录一次很多", "trophy.fill", hasLargeDay ? 1 : 0, 1),
            item(.earlyCheckIn, "早起小鸟", "早上 8 点前打卡", "sunrise.fill", hasEarlyCheckIn ? 1 : 0, 1),
            item(.comboTap, "噗噗连击", "触发吉祥物彩蛋", "sparkles", hasComboTap ? 1 : 0, 1)
        ]
    }

    @MainActor
    static func newlyUnlocked(profileID: String, in context: ModelContext) throws -> [AchievementProgress] {
        let records = try PoopRecordStore.fetchRecords(profileID: profileID, in: context)
        let progress = progressList(records: records, profileID: profileID)
        let unlockedNow = Set(progress.filter(\.isUnlocked).map(\.id.rawValue))
        let stored = unlockedIDs(profileID: profileID)
        let newIDs = unlockedNow.subtracting(stored)

        guard !newIDs.isEmpty else { return [] }

        saveUnlockedIDs(stored.union(newIDs), profileID: profileID)
        return progress.filter { newIDs.contains($0.id.rawValue) }
    }

    @MainActor
    static func markComboTap(profileID: String, in context: ModelContext) throws -> [AchievementProgress] {
        UserDefaults.standard.set(true, forKey: comboTapKey(profileID: profileID))
        return try newlyUnlocked(profileID: profileID, in: context)
    }

    private static func item(
        _ id: AchievementID,
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        _ progress: Int,
        _ target: Int
    ) -> AchievementProgress {
        AchievementProgress(
            id: id,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            progress: progress,
            target: target
        )
    }

    private static func streak(records: [PoopRecord], matches: (PoopRecord) -> Bool) -> Int {
        let recordsByDay = Dictionary(grouping: records, by: \.dayKey).compactMapValues { records in
            records.max { $0.createdAt < $1.createdAt }
        }
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: .now)
        var count = 0

        while true {
            let date = calendar.addingDays(-count, to: today)
            let key = calendar.dayKey(for: date)
            guard let record = recordsByDay[key], matches(record) else { break }
            count += 1
        }

        return count
    }

    private static func unlockedIDs(profileID: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: unlockedKey(profileID: profileID)) ?? [])
    }

    private static func saveUnlockedIDs(_ ids: Set<String>, profileID: String) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: unlockedKey(profileID: profileID))
    }

    private static func unlockedKey(profileID: String) -> String {
        "unlockedAchievements.\(profileID)"
    }

    private static func comboTapKey(profileID: String) -> String {
        "comboTapAchievement.\(profileID)"
    }
}
