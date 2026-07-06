import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PoopBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PoopBackupImportSummary {
    let profiles: [ChildProfile]
    let preferredActiveProfileID: String?
    let insertedRecords: Int
    let updatedRecords: Int

    var message: String {
        "导入完成：新增 \(insertedRecords) 条，合并 \(updatedRecords) 条"
    }
}

@MainActor
enum PoopBackupManager {
    static func exportData(
        profiles: [ChildProfile],
        activeProfileID: String,
        fallbackNickname: String,
        records: [PoopRecord]
    ) throws -> Data {
        let safeProfiles = profiles.isEmpty
            ? [ChildProfile(id: activeProfileID, nickname: fallbackNickname)]
            : profiles
        let backup = PoopDiaryBackup(
            exportedAt: .now,
            activeProfileID: activeProfileID,
            profiles: safeProfiles,
            records: records
                .sorted { lhs, rhs in
                    if lhs.profileID == rhs.profileID {
                        return lhs.date < rhs.date
                    }
                    return lhs.profileID < rhs.profileID
                }
                .map { PoopDiaryBackup.Record(record: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func importBackup(
        from url: URL,
        currentProfiles: [ChildProfile],
        in context: ModelContext
    ) throws -> PoopBackupImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        return try importData(data, currentProfiles: currentProfiles, in: context)
    }

    static func importData(
        _ data: Data,
        currentProfiles: [ChildProfile],
        in context: ModelContext
    ) throws -> PoopBackupImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(PoopDiaryBackup.self, from: data)

        guard backup.appName == PoopDiaryBackup.expectedAppName, backup.version <= PoopDiaryBackup.currentVersion else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var mergedProfiles = currentProfiles
        for profile in backup.profiles {
            mergedProfiles = ProfileStore.upsertProfile(profile, in: mergedProfiles)
        }

        var insertedRecords = 0
        var updatedRecords = 0

        for draft in backup.records {
            let normalizedDate = Calendar.poopDiary.startOfDay(for: draft.date)
            let amount = draft.didPoop ? draft.amount : .none

            if let existing = try PoopRecordStore.record(on: normalizedDate, profileID: draft.profileID, in: context) {
                existing.profileID = draft.profileID
                existing.date = normalizedDate
                existing.dayKey = Calendar.poopDiary.dayKey(for: normalizedDate)
                existing.profileDayKey = PoopRecord.makeProfileDayKey(profileID: draft.profileID, date: normalizedDate)
                existing.didPoop = draft.didPoop
                existing.amount = amount
                existing.note = draft.note
                existing.createdAt = draft.createdAt
                updatedRecords += 1
            } else {
                let record = PoopRecord(
                    id: draft.id,
                    profileID: draft.profileID,
                    date: normalizedDate,
                    didPoop: draft.didPoop,
                    amount: amount,
                    note: draft.note,
                    createdAt: draft.createdAt
                )
                context.insert(record)
                insertedRecords += 1
            }
        }

        try context.save()
        let preferredActiveProfileID = mergedProfiles.contains { $0.id == backup.activeProfileID }
            ? backup.activeProfileID
            : mergedProfiles.first?.id

        return PoopBackupImportSummary(
            profiles: mergedProfiles,
            preferredActiveProfileID: preferredActiveProfileID,
            insertedRecords: insertedRecords,
            updatedRecords: updatedRecords
        )
    }
}

private struct PoopDiaryBackup: Codable {
    static let expectedAppName = "PoopDiary"
    static let currentVersion = 1

    var appName: String
    var version: Int
    var exportedAt: Date
    var activeProfileID: String
    var profiles: [ChildProfile]
    var records: [Record]

    init(
        exportedAt: Date,
        activeProfileID: String,
        profiles: [ChildProfile],
        records: [Record]
    ) {
        self.appName = Self.expectedAppName
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.activeProfileID = activeProfileID
        self.profiles = profiles
        self.records = records
    }

    struct Record: Codable {
        var id: UUID
        var profileID: String
        var date: Date
        var didPoop: Bool
        var amount: PoopAmount
        var note: String?
        var createdAt: Date

        init(record: PoopRecord) {
            id = record.id
            profileID = record.profileID
            date = record.date
            didPoop = record.didPoop
            amount = record.amount
            note = record.note
            createdAt = record.createdAt
        }
    }
}
