import Foundation

enum DateText {
    static func todayTitle(for date: Date = .now) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).month().day().weekday(.wide))
    }

    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).month(.defaultDigits).day())
    }

    static func weekdayShort(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).weekday(.abbreviated))
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).year().month().day().weekday(.wide))
    }

    static func dayKeyRange(from startDayKey: String, through endDayKey: String) -> String {
        guard
            let start = PoopDayKey(startDayKey),
            let end = PoopDayKey(endDayKey)
        else {
            return "\(startDayKey)—\(endDayKey)"
        }

        let startText = "\(start.year)年\(start.month)月\(start.day)日"
        guard start != end else { return startText }

        if start.year == end.year {
            return "\(startText)—\(end.month)月\(end.day)日"
        }

        return "\(startText)—\(end.year)年\(end.month)月\(end.day)日"
    }
}
