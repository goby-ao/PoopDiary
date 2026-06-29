import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .today
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = ""
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID
    @AppStorage(AppPreferenceKey.profilesJSON) private var profilesJSON = ""

    private var profiles: [ChildProfile] {
        ProfileStore.profiles(from: profilesJSON)
    }

    private var needsOnboarding: Bool {
        profiles.isEmpty || childNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView()
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        TodayCheckInView()
                    }
                    .tabItem { AppTab.today.label }
                    .tag(AppTab.today)

                    NavigationStack {
                        HeatmapView()
                    }
                    .tabItem { AppTab.heatmap.label }
                    .tag(AppTab.heatmap)

                    NavigationStack {
                        StatsView()
                    }
                    .tabItem { AppTab.stats.label }
                    .tag(AppTab.stats)
                }
                .tint(.poopAccent)
            }
        }
        .onAppear(perform: bootstrapLegacyNicknameIfNeeded)
    }

    private func bootstrapLegacyNicknameIfNeeded() {
        guard profiles.isEmpty else { return }

        let nickname = childNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else { return }

        // 兼容旧版只保存昵称、还没有 profile 列表的本地数据。
        let profile = ChildProfile(id: activeProfileID, nickname: nickname)
        profilesJSON = ProfileStore.encodedProfiles([profile])
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.previewContainer())
}
