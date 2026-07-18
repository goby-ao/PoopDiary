import Foundation

enum PoopStreakCalculator {
    static func longest(records: [PoopRecord]) -> Int {
        let calendar = stableDayCalendar
        let sortedDays = Set(latestRecordsByDay(records).values
            .filter(\.didPoop)
            .map(\.dayKey))
            .compactMap(stableDate(for:))
            .sorted()

        var longest = 0
        var current = 0
        var previousDay: Date?

        for day in sortedDays {
            if let previousDay, calendar.addingDays(1, to: previousDay) == day {
                current += 1
            } else {
                current = 1
            }

            longest = max(longest, current)
            previousDay = day
        }

        return longest
    }

    static func streakEnding(on dayKey: String, records: [PoopRecord]) -> Int {
        let recordsByDay = latestRecordsByDay(records)
        let calendar = stableDayCalendar
        guard var day = stableDate(for: dayKey) else { return 0 }
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
        Dictionary(grouping: records, by: \.dayKey).compactMapValues { records in
            records.max { $0.createdAt < $1.createdAt }
        }
    }

    private static var stableDayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func stableDate(for dayKey: String) -> Date? {
        let values = dayKey.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }

        var components = DateComponents()
        components.calendar = stableDayCalendar
        components.timeZone = stableDayCalendar.timeZone
        components.year = values[0]
        components.month = values[1]
        components.day = values[2]
        return stableDayCalendar.date(from: components)
    }

    private static func stableDayKey(for date: Date) -> String {
        let components = stableDayCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day
        else {
            return ""
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
