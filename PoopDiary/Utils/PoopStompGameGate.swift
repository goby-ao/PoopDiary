import Foundation
import SwiftData

struct PoopStompGameSession: Identifiable, Equatable {
    let profileID: String
    let dayKey: String
    let streak: Int
    let duration: TimeInterval

    var id: String {
        "\(profileID)#\(dayKey)"
    }
}

struct PoopStompGameResult: Equatable {
    let score: Int
    let stompCount: Int
    let maxCombo: Int
    let duration: TimeInterval
    let cleanliness: Int
    let rank: PoopStompGameRank
    let sticker: PoopStompSticker
}

enum PoopStompGameRank: String, Equatable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"

    var title: String {
        switch self {
        case .s:
            return "闪耀清扫"
        case .a:
            return "干净利落"
        case .b:
            return "稳稳完成"
        case .c:
            return "继续加油"
        }
    }

    static func evaluate(cleanliness: Int, maxCombo: Int, mineMistakes: Int) -> PoopStompGameRank {
        if cleanliness >= 90, maxCombo >= 10, mineMistakes == 0 {
            return .s
        }
        if cleanliness >= 75, mineMistakes <= 1 {
            return .a
        }
        if cleanliness >= 50 {
            return .b
        }
        return .c
    }
}

enum PoopStompSticker: String, CaseIterable, Equatable {
    case cleanCaptain
    case comboLightning
    case rainbowRush
    case cleanKit
    case bubbleGuard
    case goldenBoot

    var symbol: String {
        switch self {
        case .cleanCaptain:
            return "🧼"
        case .comboLightning:
            return "⚡️"
        case .rainbowRush:
            return "🌈"
        case .cleanKit:
            return "🪥"
        case .bubbleGuard:
            return "🫧"
        case .goldenBoot:
            return "🥾"
        }
    }

    var title: String {
        switch self {
        case .cleanCaptain:
            return "清扫队长"
        case .comboLightning:
            return "连击闪电"
        case .rainbowRush:
            return "彩虹冲刺"
        case .cleanKit:
            return "刷刷工具包"
        case .bubbleGuard:
            return "泡泡守卫"
        case .goldenBoot:
            return "黄金靴子"
        }
    }
}

struct PoopStompStickerUnlock: Equatable {
    let sticker: PoopStompSticker
    let isNew: Bool
    let totalUnlocked: Int
    let totalAvailable: Int
}

@MainActor
enum PoopStompGameGate {
    nonisolated static let dailyDuration: TimeInterval = 52

    static func makeSessionIfEligible(
        profileID: String,
        in context: ModelContext,
        date: Date = .now
    ) throws -> PoopStompGameSession? {
        let records = try PoopRecordStore.fetchRecords(profileID: profileID, in: context)
        let dayKey = Calendar.poopDiary.dayKey(for: date)
        let recordsByDay = latestRecordsByDay(records)
        let streak = currentCheckInStreak(recordsByDay: recordsByDay, through: date)

        guard recordsByDay[dayKey] != nil else { return nil }
        guard !PoopStompGameProgressStore.hasPlayed(profileID: profileID, dayKey: dayKey) else { return nil }

        return PoopStompGameSession(
            profileID: profileID,
            dayKey: dayKey,
            streak: streak,
            duration: dailyDuration
        )
    }

    private static func currentCheckInStreak(recordsByDay: [String: PoopRecord], through date: Date) -> Int {
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: date)
        var streak = 0

        while true {
            let targetDate = calendar.addingDays(-streak, to: today)
            let key = calendar.dayKey(for: targetDate)
            guard recordsByDay[key] != nil else { break }
            streak += 1
        }

        return streak
    }

    private static func latestRecordsByDay(_ records: [PoopRecord]) -> [String: PoopRecord] {
        Dictionary(grouping: records, by: \.dayKey).compactMapValues { records in
            records.max { $0.createdAt < $1.createdAt }
        }
    }

}

@MainActor
enum PoopStompGameProgressStore {
    static func finalize(_ result: PoopStompGameResult, for session: PoopStompGameSession) -> PoopStompStickerUnlock {
        let defaults = UserDefaults.standard
        defaults.set(result.score, forKey: scoreKey(profileID: session.profileID, dayKey: session.dayKey))

        let bestKey = highScoreKey(profileID: session.profileID)
        if result.score > defaults.integer(forKey: bestKey) {
            defaults.set(result.score, forKey: bestKey)
        }

        let collectionKey = stickerKey(profileID: session.profileID)
        var unlocked = Set(defaults.stringArray(forKey: collectionKey) ?? [])
        let isNew = unlocked.insert(result.sticker.rawValue).inserted
        defaults.set(Array(unlocked).sorted(), forKey: collectionKey)

        // 当天次数最后写入，确保只有完整结算数据全部落盘后才消费资格。
        defaults.set(true, forKey: playedKey(profileID: session.profileID, dayKey: session.dayKey))

        return PoopStompStickerUnlock(
            sticker: result.sticker,
            isNew: isNew,
            totalUnlocked: unlocked.count,
            totalAvailable: PoopStompSticker.allCases.count
        )
    }

    static func highScore(profileID: String) -> Int {
        UserDefaults.standard.integer(forKey: highScoreKey(profileID: profileID))
    }

    static func hasPlayed(profileID: String, dayKey: String) -> Bool {
        UserDefaults.standard.bool(forKey: playedKey(profileID: profileID, dayKey: dayKey))
    }

    private static func playedKey(profileID: String, dayKey: String) -> String {
        "poopStompGame.played.\(profileID).\(dayKey)"
    }

    private static func scoreKey(profileID: String, dayKey: String) -> String {
        "poopStompGame.score.\(profileID).\(dayKey)"
    }

    private static func highScoreKey(profileID: String) -> String {
        // 点按范围落脚与旧版 90 秒拖动模式的分数不可直接比较。
        "poopStompGame.tapV2.highScore.\(profileID)"
    }

    private static func stickerKey(profileID: String) -> String {
        "poopStompGame.stickers.\(profileID)"
    }
}
