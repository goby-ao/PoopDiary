import Foundation
import SwiftData

@MainActor
enum PoopRecordStore {
    static func record(
        on date: Date,
        profileID: String = ProfileStore.defaultProfileID,
        in context: ModelContext
    ) throws -> PoopRecord? {
        let key = PoopRecord.makeProfileDayKey(profileID: profileID, date: date)
        let dayKey = Calendar.poopDiary.dayKey(for: date)
        var descriptor = FetchDescriptor<PoopRecord>(
            predicate: #Predicate { record in
                record.profileDayKey == key
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let record = try context.fetch(descriptor).first {
            return record
        }

        // 兼容旧版本地数据：旧记录没有 profileDayKey 时，用 dayKey + profileID 兜底查找。
        var legacyDescriptor = FetchDescriptor<PoopRecord>(
            predicate: #Predicate { record in
                record.dayKey == dayKey && record.profileID == profileID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        legacyDescriptor.fetchLimit = 1
        if let legacyRecord = try context.fetch(legacyDescriptor).first {
            legacyRecord.profileDayKey = key
            try context.save()
            return legacyRecord
        }

        return nil
    }

    @discardableResult
    static func upsert(
        date: Date = .now,
        profileID: String = ProfileStore.defaultProfileID,
        didPoop: Bool,
        amount: PoopAmount,
        note: String? = nil,
        in context: ModelContext
    ) throws -> PoopRecord {
        let normalizedDate = Calendar.poopDiary.startOfDay(for: date)
        let normalizedAmount: PoopAmount = didPoop ? (amount == .none ? .normal : amount) : .none

        // 核心规则：按 profileDayKey 查找“当前孩子的同一天记录”，有则覆盖更新，无则插入。
        if let existing = try record(on: normalizedDate, profileID: profileID, in: context) {
            existing.profileID = profileID
            existing.date = normalizedDate
            existing.dayKey = Calendar.poopDiary.dayKey(for: normalizedDate)
            existing.profileDayKey = PoopRecord.makeProfileDayKey(profileID: profileID, date: normalizedDate)
            existing.didPoop = didPoop
            existing.amount = normalizedAmount
            existing.note = note
            try context.save()
            return existing
        }

        let record = PoopRecord(
            profileID: profileID,
            date: normalizedDate,
            didPoop: didPoop,
            amount: normalizedAmount,
            note: note
        )
        context.insert(record)
        try context.save()
        return record
    }

    static func fetchRecords(
        profileID: String = ProfileStore.defaultProfileID,
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        in context: ModelContext
    ) throws -> [PoopRecord] {
        var descriptor = FetchDescriptor<PoopRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        if let startDate, let endDate {
            let start = Calendar.poopDiary.startOfDay(for: startDate)
            let end = Calendar.poopDiary.startOfDay(for: endDate)
            descriptor.predicate = #Predicate { record in
                record.profileID == profileID && record.date >= start && record.date < end
            }
        } else {
            descriptor.predicate = #Predicate { record in
                record.profileID == profileID
            }
        }

        return try context.fetch(descriptor)
    }

    static func fetchAllRecords(in context: ModelContext) throws -> [PoopRecord] {
        let descriptor = FetchDescriptor<PoopRecord>(
            sortBy: [
                SortDescriptor(\.profileID),
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }

    static func delete(_ record: PoopRecord, in context: ModelContext) throws {
        context.delete(record)
        try context.save()
    }

    static func deleteRecord(
        on date: Date,
        profileID: String = ProfileStore.defaultProfileID,
        in context: ModelContext
    ) throws {
        guard let record = try record(on: date, profileID: profileID, in: context) else { return }
        context.delete(record)
        try context.save()
    }

    static func deleteAll(profileID: String, in context: ModelContext) throws {
        let records = try fetchRecords(profileID: profileID, in: context)
        for record in records {
            context.delete(record)
        }
        try context.save()
    }
}
