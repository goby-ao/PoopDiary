import SwiftData
import SwiftUI

struct RecordEntrySheet: View {
    let day: HeatmapDay
    let profileID: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var didPoop: Bool
    @State private var amount: PoopAmount
    @State private var note: String
    @State private var errorMessage: String?
    @State private var unlockedAchievement: AchievementProgress?

    init(day: HeatmapDay, profileID: String) {
        self.day = day
        self.profileID = profileID
        _didPoop = State(initialValue: day.record?.didPoop ?? true)
        _amount = State(initialValue: day.record?.amount == PoopAmount.none ? .normal : (day.record?.amount ?? .normal))
        _note = State(initialValue: day.record?.note ?? "")
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 8) {
                            Text(DateText.fullDate(day.date))
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text(day.record == nil ? "补录这一天" : "这一天的记录")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                        }

                        HStack(spacing: 12) {
                            entryButton(title: "拉了", emoji: "💩", selected: didPoop, tint: .poopAccent) {
                                didPoop = true
                                if amount == .none { amount = .normal }
                                InteractionFeedback.play(sound: .poop, haptic: .medium)
                            }

                            entryButton(title: "没拉", emoji: "😴", selected: !didPoop, tint: .mint) {
                                didPoop = false
                                amount = .none
                                InteractionFeedback.play(sound: .sleep, haptic: .light)
                            }
                        }

                        amountChoices
                            .disabled(!didPoop)
                            .opacity(didPoop ? 1 : 0.42)

                        TextField("可选备注", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Button {
                            save()
                        } label: {
                            Label("保存记录", systemImage: "checkmark.circle.fill")
                                .font(.system(.headline, design: .rounded).weight(.black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.poopAccent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        if day.record != nil {
                            Button(role: .destructive) {
                                delete()
                            } label: {
                                Label("删除这天记录", systemImage: "trash.fill")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(22)
                }
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("记录详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel("关闭")
                    }
                }
                .alert("保存失败", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("好") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
            }

            if let unlockedAchievement {
                AchievementUnlockOverlay(achievement: unlockedAchievement) {
                    self.unlockedAchievement = nil
                    dismiss()
                }
            }
        }
    }

    private var amountChoices: some View {
        HStack(spacing: 10) {
            ForEach(PoopAmount.checkInChoices) { choice in
                Button {
                    amount = choice
                    InteractionFeedback.play(sound: sound(for: choice), haptic: choice == .large ? .heavy : .light)
                } label: {
                    VStack(spacing: 6) {
                        Text(choice.emoji)
                            .font(.system(size: 25))
                        Text(choice.title)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(amount == choice ? Color.poopAccent : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(amount == choice ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func entryButton(title: String, emoji: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.black))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(selected ? tint : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        do {
            _ = try PoopRecordStore.upsert(
                date: day.date,
                profileID: profileID,
                didPoop: didPoop,
                amount: didPoop ? amount : .none,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                in: modelContext
            )
            InteractionFeedback.reward()
            let unlocked = try AchievementManager.newlyUnlocked(profileID: profileID, in: modelContext)
            if let achievement = unlocked.first {
                unlockedAchievement = achievement
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "这一天没有保存成功，请再试一次"
        }
    }

    private func delete() {
        do {
            try PoopRecordStore.deleteRecord(on: day.date, profileID: profileID, in: modelContext)
            InteractionFeedback.play(sound: .tap, haptic: .medium)
            dismiss()
        } catch {
            errorMessage = "删除失败，请再试一次"
        }
    }

    private func sound(for amount: PoopAmount) -> SoundEffect {
        switch amount {
        case .none:
            .tap
        case .small:
            .small
        case .normal:
            .normal
        case .large:
            .large
        }
    }
}

#Preview("Record Entry") {
    RecordEntrySheet(
        day: HeatmapDay(id: Calendar.poopDiary.dayKey(for: .now), date: .now, record: nil),
        profileID: ProfileStore.defaultProfileID
    )
    .modelContainer(SampleData.previewContainer())
}
