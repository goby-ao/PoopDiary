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
}

@MainActor
enum PoopStompGameGate {
    static let requiredPoopStreak = 3
    static let dailyDuration: TimeInterval = 90

    static func makeSessionIfEligible(
        profileID: String,
        in context: ModelContext,
        date: Date = .now
    ) throws -> PoopStompGameSession? {
        let records = try PoopRecordStore.fetchRecords(profileID: profileID, in: context)
        let dayKey = Calendar.poopDiary.dayKey(for: date)
        let recordsByDay = latestRecordsByDay(records)
        let streak = currentPoopStreak(recordsByDay: recordsByDay, through: date)

        guard recordsByDay[dayKey]?.didPoop == true else { return nil }
        guard streak >= requiredPoopStreak else { return nil }
        guard !hasPlayed(profileID: profileID, dayKey: dayKey) else { return nil }

        return PoopStompGameSession(
            profileID: profileID,
            dayKey: dayKey,
            streak: streak,
            duration: dailyDuration
        )
    }

    static func markPlayed(_ session: PoopStompGameSession) {
        UserDefaults.standard.set(true, forKey: playedKey(profileID: session.profileID, dayKey: session.dayKey))
    }

    static func recordResult(_ result: PoopStompGameResult, for session: PoopStompGameSession) {
        UserDefaults.standard.set(result.score, forKey: scoreKey(profileID: session.profileID, dayKey: session.dayKey))

        let bestKey = highScoreKey(profileID: session.profileID)
        let bestScore = UserDefaults.standard.integer(forKey: bestKey)
        if result.score > bestScore {
            UserDefaults.standard.set(result.score, forKey: bestKey)
        }
    }

    static func highScore(profileID: String) -> Int {
        UserDefaults.standard.integer(forKey: highScoreKey(profileID: profileID))
    }

    private static func hasPlayed(profileID: String, dayKey: String) -> Bool {
        UserDefaults.standard.bool(forKey: playedKey(profileID: profileID, dayKey: dayKey))
    }

    private static func currentPoopStreak(recordsByDay: [String: PoopRecord], through date: Date) -> Int {
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: date)
        var streak = 0

        while true {
            let targetDate = calendar.addingDays(-streak, to: today)
            let key = calendar.dayKey(for: targetDate)
            guard recordsByDay[key]?.didPoop == true else { break }
            streak += 1
        }

        return streak
    }

    private static func latestRecordsByDay(_ records: [PoopRecord]) -> [String: PoopRecord] {
        Dictionary(grouping: records, by: \.dayKey).compactMapValues { records in
            records.max { $0.createdAt < $1.createdAt }
        }
    }

    private static func playedKey(profileID: String, dayKey: String) -> String {
        "poopStompGame.played.\(profileID).\(dayKey)"
    }

    private static func scoreKey(profileID: String, dayKey: String) -> String {
        "poopStompGame.score.\(profileID).\(dayKey)"
    }

    private static func highScoreKey(profileID: String) -> String {
        "poopStompGame.highScore.\(profileID)"
    }
}
