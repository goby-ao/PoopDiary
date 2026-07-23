import Foundation

struct PoopWeightEstimate: Equatable {
    let grams: Int

    var jin: Double {
        Double(grams) / 500
    }
}

enum PoopWeightEstimator {
    static func estimate(
        records: [PoopRecord],
        through date: Date = .now
    ) -> PoopWeightEstimate? {
        let calendar = Calendar.poopDiary
        guard let lastIncludedDayKey = PoopDayKey(calendar.dayKey(for: date)) else {
            return nil
        }

        let keyedRecords = records.compactMap { record -> (dayKey: PoopDayKey, record: PoopRecord)? in
            let rawDayKey = record.dayKey.isEmpty
                ? calendar.dayKey(for: record.date)
                : record.dayKey
            guard let dayKey = PoopDayKey(rawDayKey) else { return nil }
            return (dayKey, record)
        }
        let latestRecords = Dictionary(grouping: keyedRecords, by: \.dayKey).compactMapValues { entries in
            entries.max { $0.record.createdAt < $1.record.createdAt }?.record
        }
        let measurableRecords = latestRecords.compactMap { dayKey, record -> PoopRecord? in
            guard
                dayKey <= lastIncludedDayKey,
                record.didPoop,
                record.amount != .none
            else {
                return nil
            }
            return record
        }

        guard !measurableRecords.isEmpty else { return nil }

        let grams = measurableRecords.reduce(0) { result, record in
            result + record.amount.estimatedWetWeightGrams
        }
        return PoopWeightEstimate(grams: grams)
    }
}
