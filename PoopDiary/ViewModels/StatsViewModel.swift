import Foundation
import Observation

struct DailyCheckInStat: Identifiable {
    let id: String
    let date: Date
    let hasRecord: Bool
    let didPoop: Bool
    let amount: PoopAmount

    var statusEmoji: String {
        guard hasRecord else { return "·" }
        return didPoop ? amount.emoji : "😴"
    }
}

struct AmountDistributionSlice: Identifiable {
    let id: PoopAmount
    let amount: PoopAmount
    let count: Int

    var title: String {
        amount.title
    }
}

struct TrendPoint: Identifiable {
    let id: String
    let date: Date
    let score: Int
}

struct MonthlyReport {
    let monthTitle: String
    let totalPoopCount: Int
    let bestWeekTitle: String
    let smallCount: Int
    let normalCount: Int
    let largeCount: Int

    var totalAmountCount: Int {
        smallCount + normalCount + largeCount
    }

    func percent(for count: Int) -> Int {
        guard totalAmountCount > 0 else { return 0 }
        return Int((Double(count) / Double(totalAmountCount) * 100).rounded())
    }
}

@Observable
final class StatsViewModel {
    func currentStreak(records: [PoopRecord]) -> Int {
        let calendar = Calendar.poopDiary
        let keys = Set(records.map(\.dayKey))
        let today = calendar.startOfDay(for: .now)
        var streak = 0

        while true {
            let date = calendar.addingDays(-streak, to: today)
            let key = calendar.dayKey(for: date)
            guard keys.contains(key) else { break }
            streak += 1
        }

        return streak
    }

    func longestPoopStreak(records: [PoopRecord]) -> Int {
        PoopStreakCalculator.longest(records: records)
    }

    func currentPoopStreak(records: [PoopRecord], through date: Date = .now) -> Int {
        streak(records: records, through: date) { $0.didPoop }
    }

    func recentCheckInStats(records: [PoopRecord], days: Int = 7) -> [DailyCheckInStat] {
        let calendar = Calendar.poopDiary
        let recordsByDay = latestRecordsByDay(records)
        let today = calendar.startOfDay(for: .now)
        let start = calendar.addingDays(-(days - 1), to: today)

        return (0..<days).map { offset in
            let date = calendar.addingDays(offset, to: start)
            let key = calendar.dayKey(for: date)
            let record = recordsByDay[key]
            return DailyCheckInStat(
                id: key,
                date: date,
                hasRecord: record != nil,
                didPoop: record?.didPoop == true,
                amount: record?.amount ?? .none
            )
        }
    }

    func averagePoopPerDay(records: [PoopRecord], days: Int = 30) -> Double {
        let recent = recordsInRecentDays(records: records, days: days)
        return Double(recent.filter(\.didPoop).count) / Double(days)
    }

    func regularityRate(records: [PoopRecord], days: Int = 30) -> Double {
        let recent = recordsInRecentDays(records: records, days: days)
        let poopRecords = recent.filter(\.didPoop)
        guard !poopRecords.isEmpty else { return 0 }
        return Double(poopRecords.filter { $0.amount == .normal }.count) / Double(poopRecords.count)
    }

    func amountDistribution(records: [PoopRecord], days: Int = 30) -> [AmountDistributionSlice] {
        let recent = recordsInRecentDays(records: records, days: days)
        return PoopAmount.checkInChoices.map { amount in
            AmountDistributionSlice(
                id: amount,
                amount: amount,
                count: recent.filter { $0.didPoop && $0.amount == amount }.count
            )
        }
    }

    func trendPoints(records: [PoopRecord], days: Int = 30) -> [TrendPoint] {
        let calendar = Calendar.poopDiary
        let recordsByDay = latestRecordsByDay(records)
        let today = calendar.startOfDay(for: .now)
        let start = calendar.addingDays(-(days - 1), to: today)

        return (0..<days).map { offset in
            let date = calendar.addingDays(offset, to: start)
            let key = calendar.dayKey(for: date)
            return TrendPoint(id: key, date: date, score: recordsByDay[key]?.amount.score ?? 0)
        }
    }

    func favoriteWeekday(records: [PoopRecord]) -> String {
        let poopRecords = records.filter(\.didPoop)
        guard !poopRecords.isEmpty else { return "还在观察中" }

        let grouped = Dictionary(grouping: poopRecords) { record in
            Calendar.poopDiary.component(.weekday, from: record.date)
        }

        guard let favorite = grouped.max(by: { $0.value.count < $1.value.count }) else {
            return "还在观察中"
        }

        let sampleDate = Calendar.poopDiary.nextDate(
            after: .now,
            matching: DateComponents(weekday: favorite.key),
            matchingPolicy: .nextTime
        ) ?? .now
        return DateText.weekdayShort(sampleDate)
    }

    func monthlyProgress(records: [PoopRecord], target: Int = 20) -> Double {
        let count = currentMonthRecords(records: records).filter(\.didPoop).count
        return min(Double(count) / Double(target), 1)
    }

    func currentMonthPoopCount(records: [PoopRecord]) -> Int {
        currentMonthRecords(records: records).filter(\.didPoop).count
    }

    func healthTip(records: [PoopRecord]) -> String {
        let calendar = Calendar.poopDiary
        let recordsByDay = latestRecordsByDay(records)
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.addingDays(-1, to: today)

        let recentTwo = [yesterday, today].compactMap { recordsByDay[calendar.dayKey(for: $0)] }
        if recentTwo.count == 2, recentTwo.allSatisfy({ !$0.didPoop }) {
            return "小肚肚连续休息 2 天啦，可以轻松喝点水、吃点蔬果；这只是温柔提醒，不是医疗建议。"
        }

        return "最近记录很棒，继续把打卡当成一个轻松的小仪式就好。"
    }

    func monthlyReport(records: [PoopRecord]) -> MonthlyReport {
        let monthRecords = currentMonthRecords(records: records)
        let amountCounts = Dictionary(grouping: monthRecords.filter(\.didPoop), by: \.amount).mapValues(\.count)

        return MonthlyReport(
            monthTitle: Date().formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).year().month(.wide)),
            totalPoopCount: monthRecords.filter(\.didPoop).count,
            bestWeekTitle: bestWeekTitle(records: monthRecords),
            smallCount: amountCounts[.small] ?? 0,
            normalCount: amountCounts[.normal] ?? 0,
            largeCount: amountCounts[.large] ?? 0
        )
    }

    private func recordsInRecentDays(records: [PoopRecord], days: Int) -> [PoopRecord] {
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: .now)
        let start = calendar.addingDays(-(days - 1), to: today)
        return records.filter { $0.date >= start && $0.date <= today }
    }

    private func currentMonthRecords(records: [PoopRecord]) -> [PoopRecord] {
        let calendar = Calendar.poopDiary
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard
            let start = calendar.date(from: components),
            let end = calendar.date(byAdding: .month, value: 1, to: start)
        else {
            return []
        }

        return records.filter { $0.date >= start && $0.date < end }
    }

    private func bestWeekTitle(records: [PoopRecord]) -> String {
        let calendar = Calendar.poopDiary
        let grouped = Dictionary(grouping: records.filter { $0.didPoop && $0.amount == .normal }) { record in
            calendar.component(.weekOfMonth, from: record.date)
        }

        guard let best = grouped.max(by: { $0.value.count < $1.value.count }) else {
            return "还在积累"
        }

        return "第 \(best.key) 周"
    }

    private func streak(records: [PoopRecord], through date: Date = .now, matches: (PoopRecord) -> Bool) -> Int {
        let recordsByDay = latestRecordsByDay(records)
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: date)
        var count = 0

        while true {
            let date = calendar.addingDays(-count, to: today)
            let key = calendar.dayKey(for: date)
            guard let record = recordsByDay[key], matches(record) else { break }
            count += 1
        }

        return count
    }

    private func latestRecordsByDay(_ records: [PoopRecord]) -> [String: PoopRecord] {
        Dictionary(grouping: records, by: \.dayKey).compactMapValues { records in
            records.max { $0.createdAt < $1.createdAt }
        }
    }

}
