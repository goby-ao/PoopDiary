import Foundation

enum PersonalRecordManager {
    static func makeEvent(
        profileID: String,
        dayKey: String,
        didPoop: Bool,
        previousBest: Int,
        recordsAfterSave: [PoopRecord]
    ) -> PersonalRecordEvent? {
        guard didPoop else { return nil }

        let newBest = PoopStreakCalculator.longest(records: recordsAfterSave)
        let endingStreak = PoopStreakCalculator.streakEnding(on: dayKey, records: recordsAfterSave)
        guard newBest >= 2,
              newBest > previousBest,
              endingStreak == newBest,
              newBest > lastPresentedValue(profileID: profileID)
        else {
            return nil
        }

        let event = PersonalRecordEvent(
            kind: .longestPoopStreak,
            profileID: profileID,
            dayKey: dayKey,
            previousValue: previousBest,
            newValue: newBest
        )

        return event
    }

    static func markTriggered(_ event: PersonalRecordEvent) {
        let storedValue = lastPresentedValue(profileID: event.profileID)
        UserDefaults.standard.set(
            max(storedValue, event.newValue),
            forKey: lastPresentedKey(profileID: event.profileID)
        )
    }

    static func isValid(
        _ event: PersonalRecordEvent,
        profileID: String,
        dayKey: String,
        records: [PoopRecord]
    ) -> Bool {
        event.profileID == profileID
            && event.dayKey == dayKey
            && PoopStreakCalculator.longest(records: records) >= event.newValue
            && PoopStreakCalculator.streakEnding(on: dayKey, records: records) >= event.newValue
    }

    private static func lastPresentedValue(profileID: String) -> Int {
        UserDefaults.standard.integer(forKey: lastPresentedKey(profileID: profileID))
    }

    private static func lastPresentedKey(profileID: String) -> String {
        "personalRecord.longestPoopStreak.lastPresented.\(profileID)"
    }
}
