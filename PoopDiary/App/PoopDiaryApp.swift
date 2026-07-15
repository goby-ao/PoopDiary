import SwiftData
import SwiftUI

@main
struct PoopDiaryApp: App {
    @StateObject private var persistence = PersistenceController()

    var body: some Scene {
        WindowGroup {
            PersistenceContainerView()
                .environmentObject(persistence)
        }
    }
}

private struct PersistenceContainerView: View {
    @EnvironmentObject private var persistence: PersistenceController

    var body: some View {
        Group {
            switch persistence.state {
            case .loading:
                ProgressView("正在加载本地数据...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.poopCream)
            case .ready(let container):
                RootTabView()
                    .modelContainer(container)
            case .failed(let issue):
                PersistenceRecoveryView(issue: issue)
                    .environmentObject(persistence)
            }
        }
    }
}
