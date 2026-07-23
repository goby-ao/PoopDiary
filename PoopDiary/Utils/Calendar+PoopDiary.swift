import Foundation

struct PoopDayKey: Hashable, Comparable {
    let rawValue: String
    let year: Int
    let month: Int
    let day: Int

    init?(_ rawValue: String) {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            parts[0].count == 4,
            parts[1].count == 2,
            parts[2].count == 2,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        let date = Self.stableCalendar.date(from: DateComponents(
            calendar: Self.stableCalendar,
            timeZone: Self.stableCalendar.timeZone,
            year: year,
            month: month,
            day: day
        ))
        guard let date else { return nil }

        let validated = Self.stableCalendar.dateComponents([.year, .month, .day], from: date)
        guard
            validated.year == year,
            validated.month == month,
            validated.day == day,
            String(format: "%04d-%02d-%02d", year, month, day) == rawValue
        else {
            return nil
        }

        self.rawValue = rawValue
        self.year = year
        self.month = month
        self.day = day
    }

    var stableDate: Date {
        Self.stableCalendar.date(from: DateComponents(
            calendar: Self.stableCalendar,
            timeZone: Self.stableCalendar.timeZone,
            year: year,
            month: month,
            day: day
        ))!
    }

    static func < (lhs: PoopDayKey, rhs: PoopDayKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static var stableCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

extension Calendar {
    static var poopDiary: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    func dayKey(for date: Date) -> String {
        let components = dateComponents([.year, .month, .day], from: startOfDay(for: date))
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func addingDays(_ days: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: days, to: date) ?? date
    }
}
