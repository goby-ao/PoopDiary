import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersistenceController: ObservableObject {
    enum State {
        case loading
        case ready(ModelContainer)
        case failed(PersistenceIssue)
    }

    @Published private(set) var state: State = .loading

    init() {
        loadContainer()
    }

    func loadContainer() {
        state = .loading

        do {
            state = .ready(try ModelContainer(for: PoopRecord.self))
        } catch {
            state = .failed(PersistenceIssue(
                title: "本地数据加载失败",
                message: Self.errorMessage(for: error),
                recoveryHint: "通常是旧版本数据或本地库文件异常。可以先重试；如果仍失败，可把旧数据备份到 App 沙盒后重建一个空库。"
            ))
        }
    }

    func backUpStoreAndReload() {
        state = .loading

        do {
            _ = try Self.backUpStoreFiles()
            loadContainer()
        } catch {
            state = .failed(PersistenceIssue(
                title: "数据修复失败",
                message: Self.errorMessage(for: error),
                recoveryHint: "旧数据仍保留在原位置或完整备份中。请先退出 App 后重试，或从电脑端导出沙盒数据再处理。"
            ))
        }
    }

    private static func backUpStoreFiles() throws -> URL? {
        let fileManager = FileManager.default
        let supportURL = try applicationSupportDirectory()
        let storeNames = ["default.store", "default.store-shm", "default.store-wal"]
        let existingStores = storeNames
            .map { supportURL.appendingPathComponent($0) }
            .filter { fileManager.fileExists(atPath: $0.path) }

        guard !existingStores.isEmpty else { return nil }

        let backupsURL = supportURL.appendingPathComponent("StoreBackups", isDirectory: true)
        try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter()
            .string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let backupURL = backupsURL.appendingPathComponent("\(timestamp)-\(uniqueSuffix)", isDirectory: true)
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

        do {
            for storeURL in existingStores {
                try fileManager.copyItem(
                    at: storeURL,
                    to: backupURL.appendingPathComponent(storeURL.lastPathComponent)
                )
            }
            try writeBackupManifest(storeURLs: existingStores, to: backupURL)
        } catch {
            try? fileManager.removeItem(at: backupURL)
            throw error
        }

        var removedStores: [URL] = []
        do {
            for storeURL in existingStores {
                try fileManager.removeItem(at: storeURL)
                removedStores.append(storeURL)
            }
        } catch {
            // 删除任一文件失败时，尽力从完整副本回滚，避免 SQLite 三件套被拆散。
            for storeURL in removedStores where !fileManager.fileExists(atPath: storeURL.path) {
                let backupStoreURL = backupURL.appendingPathComponent(storeURL.lastPathComponent)
                try? fileManager.copyItem(at: backupStoreURL, to: storeURL)
            }
            throw error
        }

        return backupURL
    }

    private static func writeBackupManifest(storeURLs: [URL], to backupURL: URL) throws {
        let defaults = UserDefaults.standard
        let manifest = StoreBackupManifest(
            formatVersion: 1,
            createdAt: .now,
            storeFiles: storeURLs.map(\.lastPathComponent).sorted(),
            profilesJSON: defaults.string(forKey: AppPreferenceKey.profilesJSON),
            activeProfileID: defaults.string(forKey: AppPreferenceKey.activeProfileID),
            childNickname: defaults.string(forKey: AppPreferenceKey.childNickname)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: backupURL.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private static func applicationSupportDirectory() throws -> URL {
        let fileManager = FileManager.default
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        return supportURL
    }

    private static func errorMessage(for error: Error) -> String {
        let message = error.localizedDescription
        let detail = String(describing: error)

        if detail == message {
            return message
        }

        return "\(message)\n\(detail)"
    }
}

private struct StoreBackupManifest: Codable {
    let formatVersion: Int
    let createdAt: Date
    let storeFiles: [String]
    let profilesJSON: String?
    let activeProfileID: String?
    let childNickname: String?
}

struct PersistenceIssue {
    var title: String
    var message: String
    var recoveryHint: String
}

struct PersistenceRecoveryView: View {
    @EnvironmentObject private var persistence: PersistenceController
    @State private var isConfirmingReset = false

    let issue: PersistenceIssue

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.poopAccent)

            VStack(spacing: 10) {
                Text(issue.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text(issue.recoveryHint)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(issue.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 12) {
                Button("重试") {
                    persistence.loadContainer()
                }
                .buttonStyle(.borderedProminent)
                .tint(.poopAccent)

                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Text("备份旧数据并重建空库")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.poopCream)
        .confirmationDialog("确认重建空白本地库？", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("备份旧数据并重建空库", role: .destructive) {
                persistence.backUpStoreAndReload()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("App 会先把旧库和孩子档案信息完整复制到 StoreBackups，再重建空库。原记录不会自动恢复，可通过电脑导出 App 沙盒备份。")
        }
    }
}
