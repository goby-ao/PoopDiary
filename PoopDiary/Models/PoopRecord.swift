import Foundation
import SwiftData

@Model
final class PoopRecord {
    @Attribute(.unique) var id: UUID
    var profileDayKey: String = ""
    var profileID: String = ProfileStore.defaultProfileID
    var dayKey: String = ""
    var date: Date
    var didPoop: Bool
    var amountRawValue: String
    var note: String?
    var createdAt: Date

    var amount: PoopAmount {
        get { PoopAmount(rawValue: amountRawValue) ?? .none }
        set { amountRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        profileID: String = ProfileStore.defaultProfileID,
        date: Date,
        didPoop: Bool,
        amount: PoopAmount,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        let normalizedDate = Calendar.poopDiary.startOfDay(for: date)
        self.id = id
        self.profileID = profileID
        self.dayKey = Calendar.poopDiary.dayKey(for: normalizedDate)
        self.profileDayKey = Self.makeProfileDayKey(profileID: profileID, date: normalizedDate)
        self.date = normalizedDate
        self.didPoop = didPoop
        self.amountRawValue = didPoop ? amount.rawValue : PoopAmount.none.rawValue
        self.note = note
        self.createdAt = createdAt
    }

    static func makeProfileDayKey(profileID: String, date: Date) -> String {
        // 多孩子模式下，同一天是否唯一要按“孩子 + 日期”判断。
        "\(profileID)#\(Calendar.poopDiary.dayKey(for: date))"
    }
}
