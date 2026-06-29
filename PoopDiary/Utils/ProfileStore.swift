import Foundation

struct ChildProfile: Codable, Identifiable, Hashable {
    var id: String
    var nickname: String
    var createdAt: Date

    init(id: String = UUID().uuidString, nickname: String, createdAt: Date = .now) {
        self.id = id
        self.nickname = nickname
        self.createdAt = createdAt
    }
}

extension AppPreferenceKey {
    static let childNickname = "childNickname"
    static let activeProfileID = "activeProfileID"
    static let profilesJSON = "profilesJSON"
    static let dailyReminderEnabled = "dailyReminderEnabled"
    static let dailyReminderHour = "dailyReminderHour"
    static let dailyReminderMinute = "dailyReminderMinute"
    static let parentLockEnabled = "parentLockEnabled"
}

enum ProfileStore {
    static let defaultProfileID = "default-child"

    static let nicknameSuggestions = [
        "便便小超人",
        "黄金战士",
        "粑粑探险家",
        "小肚肚队长",
        "彩虹小勇士"
    ]

    static func profiles(from json: String) -> [ChildProfile] {
        guard let data = json.data(using: .utf8), !json.isEmpty else { return [] }
        return (try? JSONDecoder().decode([ChildProfile].self, from: data)) ?? []
    }

    static func encodedProfiles(_ profiles: [ChildProfile]) -> String {
        guard let data = try? JSONEncoder().encode(profiles) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func cleanNickname(_ nickname: String) -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "便便小超人" : trimmed
    }

    static func activeProfile(in profiles: [ChildProfile], activeProfileID: String) -> ChildProfile? {
        profiles.first { $0.id == activeProfileID } ?? profiles.first
    }

    static func upsertProfile(_ profile: ChildProfile, in profiles: [ChildProfile]) -> [ChildProfile] {
        var nextProfiles = profiles

        if let index = nextProfiles.firstIndex(where: { $0.id == profile.id }) {
            nextProfiles[index] = profile
        } else {
            nextProfiles.append(profile)
        }

        return nextProfiles.sorted { $0.createdAt < $1.createdAt }
    }
}
