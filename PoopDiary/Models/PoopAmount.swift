import Foundation

enum PoopAmount: String, Codable, CaseIterable, Identifiable {
    case none
    case small
    case normal
    case large

    var id: String { rawValue }

    static let checkInChoices: [PoopAmount] = [.small, .normal, .large]

    var title: String {
        switch self {
        case .none:
            "没拉"
        case .small:
            "少量"
        case .normal:
            "正常"
        case .large:
            "很多"
        }
    }

    var emoji: String {
        switch self {
        case .none:
            "😴"
        case .small:
            "💧"
        case .normal:
            "🎉"
        case .large:
            "🏆"
        }
    }

    var score: Int {
        switch self {
        case .none:
            0
        case .small:
            1
        case .normal:
            2
        case .large:
            3
        }
    }

    /// 仅用于趣味累计估算，不代表实际称重或健康判断。
    var estimatedWetWeightGrams: Int {
        switch self {
        case .none:
            0
        case .small:
            50
        case .normal:
            150
        case .large:
            200
        }
    }
}
