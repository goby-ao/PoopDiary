import Foundation

struct PoopStreakPeriod: Equatable {
    let dayCount: Int
    let startDayKey: String
    let endDayKey: String
}

enum PoopStreakCalculator {
    static func longest(records: [PoopRecord]) -> Int {
        calculateLongestPeriod(records: records, throughDayKey: nil) {
            $0.didPoop
        }?.dayCount ?? 0
    }

    static func longestPeriod(
        records: [PoopRecord],
        through date: Date = .now,
        matching predicate: (PoopRecord) -> Bool
    ) -> PoopStreakPeriod? {
        calculateLongestPeriod(
            records: records,
            throughDayKey: PoopDayKey(Calendar.poopDiary.dayKey(for: date)),
            matching: predicate
        )
    }

    private static func calculateLongestPeriod(
        records: [PoopRecord],
        throughDayKey: PoopDayKey?,
        matching predicate: (PoopRecord) -> Bool
    ) -> PoopStreakPeriod? {
        let calendar = PoopDayKey.stableCalendar
        let sortedDays = latestRecordsByDay(records)
            .compactMap { rawDayKey, record -> PoopDayKey? in
                guard
                    predicate(record),
                    let dayKey = PoopDayKey(rawDayKey),
                    throughDayKey.map({ dayKey <= $0 }) ?? true
                else {
                    return nil
                }
                return dayKey
            }
            .sorted()

        var bestPeriod: PoopStreakPeriod?
        var current = 0
        var currentStartDayKey: String?
        var previousDay: Date?

        for day in sortedDays {
            if let previousDay, calendar.addingDays(1, to: previousDay) == day.stableDate {
                current += 1
            } else {
                current = 1
                currentStartDayKey = day.rawValue
            }

            if current >= (bestPeriod?.dayCount ?? 0), let currentStartDayKey {
                bestPeriod = PoopStreakPeriod(
                    dayCount: current,
                    startDayKey: currentStartDayKey,
                    endDayKey: day.rawValue
                )
            }
            previousDay = day.stableDate
        }

        return bestPeriod
    }

    static func streakEnding(on dayKey: String, records: [PoopRecord]) -> Int {
        let recordsByDay = latestRecordsByDay(records)
        let calendar = PoopDayKey.stableCalendar
        guard var day = PoopDayKey(dayKey)?.stableDate else { return 0 }
        var count = 0

        while true {
            let key = stableDayKey(for: day)
            guard recordsByDay[key]?.didPoop == true else { break }
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        return count
    }

    private static func latestRecordsByDay(_ records: [PoopRecord]) -> [String: PoopRecord] {
        let keyedRecords = records.compactMap { record -> (dayKey: String, record: PoopRecord)? in
            let rawDayKey = record.dayKey.isEmpty
                ? Calendar.poopDiary.dayKey(for: record.date)
                : record.dayKey
            guard PoopDayKey(rawDayKey) != nil else { return nil }
            return (rawDayKey, record)
        }
        return Dictionary(grouping: keyedRecords, by: \.dayKey).compactMapValues { entries in
            entries.max { $0.record.createdAt < $1.record.createdAt }?.record
        }
    }

    private static func stableDayKey(for date: Date) -> String {
        let components = PoopDayKey.stableCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day
        else {
            return ""
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
