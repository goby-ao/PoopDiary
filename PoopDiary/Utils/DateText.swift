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
}
