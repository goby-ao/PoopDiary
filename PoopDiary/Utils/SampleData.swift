import Foundation
import SwiftData

@MainActor
enum SampleData {
    static func emptyPreviewContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: PoopRecord.self, configurations: configuration)
    }

    static func previewContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PoopRecord.self, configurations: configuration)
        seedPreviewData(in: container.mainContext)
        return container
    }

    static func seedPreviewData(in context: ModelContext) {
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: .now)
        let profileID = ProfileStore.defaultProfileID

        for offset in 0..<60 {
            let date = calendar.addingDays(-offset, to: today)

            if offset % 9 == 0 {
                _ = try? PoopRecordStore.upsert(date: date, profileID: profileID, didPoop: false, amount: .none, in: context)
                continue
            }

            let amount: PoopAmount
            switch offset % 5 {
            case 0:
                amount = .large
            case 1, 4:
                amount = .normal
            default:
                amount = .small
            }

            _ = try? PoopRecordStore.upsert(date: date, profileID: profileID, didPoop: true, amount: amount, in: context)
        }
    }
}
