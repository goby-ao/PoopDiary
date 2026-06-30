import Foundation

enum CSVExporter {
    static func export(records: [PoopRecord], nickname: String) throws -> URL {
        let sortedRecords = records.sorted { $0.date < $1.date }
        let rows = sortedRecords.map { record in
            [
                Calendar.poopDiary.dayKey(for: record.date),
                record.didPoop ? "拉了" : "没拉",
                record.amount.title,
                record.note ?? ""
            ].map(escape).joined(separator: ",")
        }

        let csv = (["日期,状态,量,备注"] + rows).joined(separator: "\n")
        let safeNickname = nickname.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(safeNickname)-便便超人.csv"
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
