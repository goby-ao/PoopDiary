import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct FeedbackSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferenceKey.soundEnabled) private var soundEnabled = true
    @AppStorage(AppPreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = "便便小超人"
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID
    @AppStorage(AppPreferenceKey.profilesJSON) private var profilesJSON = ""
    @AppStorage(AppPreferenceKey.dailyReminderEnabled) private var reminderEnabled = false
    @AppStorage(AppPreferenceKey.dailyReminderHour) private var reminderHour = 20
    @AppStorage(AppPreferenceKey.dailyReminderMinute) private var reminderMinute = 0
    @AppStorage(AppPreferenceKey.parentLockEnabled) private var parentLockEnabled = false
    @State private var nicknameDraft = ""
    @State private var newProfileName = ""
    @State private var csvURL: URL?
    @State private var backupDocument = PoopBackupDocument()
    @State private var backupFileName = "PoopDiary-Backup"
    @State private var alertMessage: String?
    @State private var showingDeleteConfirm = false
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false

    private var profiles: [ChildProfile] {
        ProfileStore.profiles(from: profilesJSON)
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                dataSection
                reminderSection
                feedbackSection
                parentSection
            }
            .navigationTitle("家长设置")
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
            .onAppear {
                bootstrapProfilesIfNeeded()
                nicknameDraft = ProfileStore.cleanNickname(childNickname)
            }
            .onChange(of: activeProfileID) { _, _ in
                syncActiveProfileName()
            }
            .confirmationDialog("确认删除当前孩子的所有记录？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除记录", role: .destructive) {
                    deleteCurrentProfileRecords()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会删除当前设备里当前孩子的记录，不会影响备份文件和其他孩子。")
            }
            .alert("提示", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("好") { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
            .fileExporter(
                isPresented: $showingBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupFileName
            ) { result in
                handleBackupExportResult(result)
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.json]
            ) { result in
                importBackup(result)
            }
        }
    }

    private var profileSection: some View {
        Section("孩子档案") {
            Picker("当前孩子", selection: $activeProfileID) {
                ForEach(profiles) { profile in
                    Text(profile.nickname).tag(profile.id)
                }
            }

            TextField("昵称", text: $nicknameDraft)

            Button {
                saveNickname()
            } label: {
                Label("保存昵称", systemImage: "checkmark.circle.fill")
            }

            HStack {
                TextField("新增孩子昵称", text: $newProfileName)

                Button {
                    addProfile()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("新增孩子")
            }
        }
    }

    private var dataSection: some View {
        Section("历史数据") {
            NavigationLink {
                ImportRecordsView(profileID: activeProfileID, nickname: ProfileStore.cleanNickname(childNickname))
            } label: {
                Label("导入文本记录", systemImage: "square.and.arrow.down.fill")
            }

            Button {
                exportCSV()
            } label: {
                Label("生成 CSV", systemImage: "tablecells.fill")
            }

            if let csvURL {
                ShareLink(item: csvURL) {
                    Label("分享 CSV", systemImage: "square.and.arrow.up.fill")
                }
            }

            Button {
                exportBackup()
            } label: {
                Label("备份到 iCloud Drive", systemImage: "icloud.and.arrow.up")
            }

            Button {
                showingBackupImporter = true
            } label: {
                Label("从备份文件合并", systemImage: "icloud.and.arrow.down")
            }

            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("删除当前孩子记录", systemImage: "trash.fill")
            }
        }
    }

    private var reminderSection: some View {
        Section("每日提醒") {
            Toggle(isOn: Binding(
                get: { reminderEnabled },
                set: { value in
                    reminderEnabled = value
                    updateReminder()
                }
            )) {
                Label("提醒打卡", systemImage: "bell.badge.fill")
            }

            DatePicker("提醒时间", selection: reminderDateBinding, displayedComponents: .hourAndMinute)
                .disabled(!reminderEnabled)
        }
    }

    private var feedbackSection: some View {
        Section("互动反馈") {
            Toggle(isOn: $soundEnabled) {
                Label("音效", systemImage: "speaker.wave.2.fill")
            }

            Toggle(isOn: $hapticsEnabled) {
                Label("震动", systemImage: "iphone.radiowaves.left.and.right")
            }
        }
    }

    private var parentSection: some View {
        Section("家长区") {
            Toggle(isOn: $parentLockEnabled) {
                Label("简单家长锁", systemImage: "lock.shield.fill")
            }

            Text(parentLockEnabled ? "已预留家长锁入口，后续可接入手势或密码。" : "删除、导入、切档案都集中在这里，方便家长管理。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var reminderDateBinding: Binding<Date> {
        Binding {
            var components = Calendar.poopDiary.dateComponents([.year, .month, .day], from: .now)
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.poopDiary.date(from: components) ?? Date()
        } set: { date in
            let components = Calendar.poopDiary.dateComponents([.hour, .minute], from: date)
            reminderHour = components.hour ?? 20
            reminderMinute = components.minute ?? 0
            updateReminder()
        }
    }

    private func bootstrapProfilesIfNeeded() {
        guard profiles.isEmpty else { return }
        let profile = ChildProfile(id: activeProfileID, nickname: ProfileStore.cleanNickname(childNickname))
        profilesJSON = ProfileStore.encodedProfiles([profile])
    }

    private func syncActiveProfileName() {
        guard let profile = ProfileStore.activeProfile(in: profiles, activeProfileID: activeProfileID) else { return }
        childNickname = profile.nickname
        nicknameDraft = profile.nickname
        InteractionFeedback.play(sound: .tap, haptic: .light)
    }

    private func saveNickname() {
        let nickname = ProfileStore.cleanNickname(nicknameDraft)
        let active = ProfileStore.activeProfile(in: profiles, activeProfileID: activeProfileID) ?? ChildProfile(id: activeProfileID, nickname: nickname)
        let updatedProfile = ChildProfile(id: active.id, nickname: nickname, createdAt: active.createdAt)
        profilesJSON = ProfileStore.encodedProfiles(ProfileStore.upsertProfile(updatedProfile, in: profiles))
        activeProfileID = updatedProfile.id
        childNickname = nickname
        nicknameDraft = nickname
        alertMessage = "昵称已保存"
        InteractionFeedback.reward()
    }

    private func addProfile() {
        let nickname = ProfileStore.cleanNickname(newProfileName)
        let profile = ChildProfile(nickname: nickname)
        profilesJSON = ProfileStore.encodedProfiles(ProfileStore.upsertProfile(profile, in: profiles))
        activeProfileID = profile.id
        childNickname = profile.nickname
        nicknameDraft = profile.nickname
        newProfileName = ""
        InteractionFeedback.reward()
    }

    private func exportCSV() {
        do {
            let records = try PoopRecordStore.fetchRecords(profileID: activeProfileID, in: modelContext)
            csvURL = try CSVExporter.export(records: records, nickname: ProfileStore.cleanNickname(childNickname))
            alertMessage = "CSV 已生成，可以点击分享"
            InteractionFeedback.reward()
        } catch {
            alertMessage = "CSV 生成失败，请再试一次"
        }
    }

    private func exportBackup() {
        do {
            let records = try PoopRecordStore.fetchAllRecords(in: modelContext)
            backupDocument = PoopBackupDocument(data: try PoopBackupManager.exportData(
                profiles: profiles,
                activeProfileID: activeProfileID,
                fallbackNickname: ProfileStore.cleanNickname(childNickname),
                records: records
            ))
            backupFileName = makeBackupFileName()
            showingBackupExporter = true
            InteractionFeedback.play(sound: .tap, haptic: .light)
        } catch {
            alertMessage = "备份生成失败，请再试一次"
        }
    }

    private func handleBackupExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            alertMessage = "备份已保存"
            InteractionFeedback.reward()
        case .failure:
            alertMessage = "备份保存失败，请再试一次"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let summary = try PoopBackupManager.importBackup(
                from: url,
                currentProfiles: profiles,
                in: modelContext
            )
            profilesJSON = ProfileStore.encodedProfiles(summary.profiles)
            if let preferredActiveProfileID = summary.preferredActiveProfileID,
               let active = ProfileStore.activeProfile(in: summary.profiles, activeProfileID: preferredActiveProfileID) {
                activeProfileID = active.id
                childNickname = active.nickname
                nicknameDraft = active.nickname
            } else if let first = summary.profiles.first {
                activeProfileID = first.id
                childNickname = first.nickname
                nicknameDraft = first.nickname
            }
            alertMessage = summary.message
            InteractionFeedback.reward()
        } catch {
            alertMessage = "备份导入失败，请确认选择的是便便超人备份文件"
        }
    }

    private func makeBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.poopDiary
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "PoopDiary-\(formatter.string(from: .now))"
    }

    private func deleteCurrentProfileRecords() {
        do {
            try PoopRecordStore.deleteAll(profileID: activeProfileID, in: modelContext)
            alertMessage = "当前孩子的记录已删除"
            InteractionFeedback.play(sound: .tap, haptic: .medium)
        } catch {
            alertMessage = "删除失败，请再试一次"
        }
    }

    private func updateReminder() {
        guard reminderEnabled else {
            NotificationManager.cancelDailyReminder()
            return
        }

        Task {
            do {
                try await NotificationManager.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
            } catch {
                await MainActor.run {
                    alertMessage = "提醒设置失败，请检查通知权限"
                }
            }
        }
    }
}

#Preview {
    FeedbackSettingsView()
        .modelContainer(SampleData.previewContainer())
}
