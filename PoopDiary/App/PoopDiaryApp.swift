import SwiftData
import SwiftUI

@main
struct PoopDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: PoopRecord.self)
    }
}
