import Foundation

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

struct AchievementProgress: Identifiable, Hashable, Codable {
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
