import Foundation

enum CheckInRewardStore {
    static func pendingRewards(profileID: String, dayKey: String) -> [CheckInRewardPresentation] {
        let rewards = load(profileID: profileID)
        let currentRewards = rewards.filter { $0.profileID == profileID && $0.dayKey == dayKey }

        if currentRewards.count != rewards.count {
            _ = save(currentRewards, profileID: profileID)
        }

        return currentRewards
    }

    @discardableResult
    static func append(_ reward: CheckInRewardPresentation) -> Bool {
        var rewards = load(profileID: reward.profileID)
        guard !rewards.contains(where: { $0.id == reward.id }) else { return true }
        rewards.append(reward)
        return save(rewards, profileID: reward.profileID)
    }

    static func remove(_ reward: CheckInRewardPresentation) {
        var rewards = load(profileID: reward.profileID)
        rewards.removeAll { $0.id == reward.id }
        _ = save(rewards, profileID: reward.profileID)
    }

    static func clear(profileID: String, dayKey: String) {
        var rewards = load(profileID: profileID)
        rewards.removeAll { $0.dayKey == dayKey }
        _ = save(rewards, profileID: profileID)
    }

    private static func load(profileID: String) -> [CheckInRewardPresentation] {
        guard let data = UserDefaults.standard.data(forKey: key(profileID: profileID)),
              let rewards = try? JSONDecoder().decode([CheckInRewardPresentation].self, from: data)
        else {
            return []
        }
        return rewards
    }

    private static func save(_ rewards: [CheckInRewardPresentation], profileID: String) -> Bool {
        guard !rewards.isEmpty else {
            UserDefaults.standard.removeObject(forKey: key(profileID: profileID))
            return true
        }
        guard let data = try? JSONEncoder().encode(rewards) else { return false }
        UserDefaults.standard.set(data, forKey: key(profileID: profileID))
        return true
    }

    private static func key(profileID: String) -> String {
        "checkInRewards.pending.\(profileID)"
    }
}
