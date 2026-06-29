import SwiftData
import SwiftUI

struct ImportRecordsView: View {
    let profileID: String
    let nickname: String
    @Environment(\.modelContext) private var modelContext
    @State private var importText = """
    2026.04.17 拉了，正常
    2026.05.02 拉了，很多
    2026.05.05 没拉
    """
    @State private var resultMessage: String?
    @State private var unlockedAchievement: AchievementProgress?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(nickname) 的历史记录")
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text("每行格式：2026.04.17 拉了，正常 / 2026.05.05 没拉")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $importText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 260)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button {
                        importRecords()
                    } label: {
                        Label("开始导入", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.poopAccent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if let resultMessage {
                        Text(resultMessage)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.poopPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(20)
            }

            if let unlockedAchievement {
                AchievementUnlockOverlay(achievement: unlockedAchievement) {
                    withAnimation {
                        self.unlockedAchievement = nil
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("导入记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func importRecords() {
        let parseResult = PoopImportParser.parse(importText)
        var successCount = 0
        var saveFailedCount = 0

        for draft in parseResult.drafts {
            do {
                _ = try PoopRecordStore.upsert(
                    date: draft.date,
                    profileID: profileID,
                    didPoop: draft.didPoop,
                    amount: draft.amount,
                    in: modelContext
                )
                successCount += 1
            } catch {
                saveFailedCount += 1
            }
        }

        let skippedCount = parseResult.failedLines.count + saveFailedCount
        resultMessage = "导入成功 \(successCount) 条，跳过 \(skippedCount) 条"
        InteractionFeedback.reward()

        if let unlocked = try? AchievementManager.newlyUnlocked(profileID: profileID, in: modelContext),
           let achievement = unlocked.first {
            unlockedAchievement = achievement
        }
    }
}

#Preview("Import") {
    NavigationStack {
        ImportRecordsView(profileID: ProfileStore.defaultProfileID, nickname: "便便小超人")
    }
    .modelContainer(SampleData.previewContainer())
}
