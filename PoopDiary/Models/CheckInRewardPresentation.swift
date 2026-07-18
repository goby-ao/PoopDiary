import Foundation

enum PersonalRecordKind: String, Codable, Hashable {
    case longestPoopStreak
}

struct PersonalRecordEvent: Identifiable, Codable, Hashable {
    let kind: PersonalRecordKind
    let profileID: String
    let dayKey: String
    let previousValue: Int
    let newValue: Int

    var id: String {
        "\(profileID)#\(dayKey)#\(kind.rawValue)#\(newValue)"
    }

    var isMajorMilestone: Bool {
        [7, 14, 30, 50, 100].contains(newValue)
    }
}

struct CheckInRewardPresentation: Identifiable, Codable {
    let profileID: String
    let dayKey: String
    let personalRecord: PersonalRecordEvent?
    let achievements: [AchievementProgress]

    var id: String {
        let recordID = personalRecord?.id ?? "no-record"
        let achievementIDs = achievements.map(\.id.rawValue).sorted().joined(separator: ",")
        return "\(profileID)#\(dayKey)#\(recordID)#\(achievementIDs)"
    }

    var usesFullCelebration: Bool {
        personalRecord?.isMajorMilestone == true || !achievements.isEmpty
    }
}
