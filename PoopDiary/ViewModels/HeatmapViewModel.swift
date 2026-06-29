import Foundation
import Observation

struct HeatmapDay: Identifiable, Hashable {
    let id: String
    let date: Date
    let record: PoopRecord?

    static func == (lhs: HeatmapDay, rhs: HeatmapDay) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
final class HeatmapViewModel {
    func recentDays(records: [PoopRecord], count: Int = 91) -> [HeatmapDay] {
        let calendar = Calendar.poopDiary
        let today = calendar.startOfDay(for: .now)
        let start = calendar.addingDays(-(count - 1), to: today)

        // SwiftData 理论上已保证 dayKey 唯一，这里仍取最新一条，方便预览或迁移数据容错。
        let recordsByDay = Dictionary(grouping: records, by: \.dayKey)
            .mapValues { records in
                records.max { $0.createdAt < $1.createdAt }
            }

        return (0..<count).map { index in
            let date = calendar.addingDays(index, to: start)
            let key = calendar.dayKey(for: date)
            return HeatmapDay(id: key, date: date, record: recordsByDay[key] ?? nil)
        }
    }

    func weeks(from days: [HeatmapDay]) -> [[HeatmapDay]] {
        stride(from: 0, to: days.count, by: 7).map { start in
            let end = min(start + 7, days.count)
            return Array(days[start..<end])
        }
    }

    func monthGrid(for month: Date, records: [PoopRecord]) -> [HeatmapDay?] {
        let calendar = Calendar.poopDiary
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? calendar.startOfDay(for: month)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let leadingBlankCount = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let recordsByDay = Dictionary(grouping: records, by: \.dayKey).mapValues { records in
            records.max { $0.createdAt < $1.createdAt }
        }

        var grid: [HeatmapDay?] = Array(repeating: nil, count: leadingBlankCount)

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let key = calendar.dayKey(for: date)
            grid.append(HeatmapDay(id: key, date: date, record: recordsByDay[key] ?? nil))
        }

        while !grid.count.isMultiple(of: 7) {
            grid.append(nil)
        }

        return grid
    }

    func monthTitle(for month: Date) -> String {
        month.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).year().month(.wide))
    }
}
