import Foundation

struct PoopImportDraft: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let didPoop: Bool
    let amount: PoopAmount
    let sourceLine: String
}

struct PoopImportParseResult {
    let drafts: [PoopImportDraft]
    let failedLines: [String]
}

enum PoopImportParser {
    static func parse(_ text: String) -> PoopImportParseResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var drafts: [PoopImportDraft] = []
        var failedLines: [String] = []

        for line in lines {
            if let draft = parseLine(line) {
                drafts.append(draft)
            } else {
                failedLines.append(line)
            }
        }

        return PoopImportParseResult(drafts: drafts, failedLines: failedLines)
    }

    private static func parseLine(_ line: String) -> PoopImportDraft? {
        let parts = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard parts.count == 2 else { return nil }

        let dateText = String(parts[0])
        let body = String(parts[1])
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: " ", with: "")

        guard let date = dateFormatter.date(from: dateText) else { return nil }

        if body.contains("没拉") {
            return PoopImportDraft(date: date, didPoop: false, amount: .none, sourceLine: line)
        }

        guard body.contains("拉了") else { return nil }

        let amount: PoopAmount
        if body.contains("少量") || body.contains("少") {
            amount = .small
        } else if body.contains("正常") {
            amount = .normal
        } else if body.contains("很多") || body.contains("大量") {
            amount = .large
        } else {
            return nil
        }

        return PoopImportDraft(date: date, didPoop: true, amount: amount, sourceLine: line)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.poopDiary
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.isLenient = false
        return formatter
    }()
}
