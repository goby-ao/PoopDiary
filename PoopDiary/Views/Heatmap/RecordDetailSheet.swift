import SwiftUI

struct RecordDetailSheet: View {
    let day: HeatmapDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text(DateText.fullDate(day.date))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                detailBadge
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }
            }
        }
    }

    private var title: String {
        guard let record = day.record else {
            return "还没打卡"
        }

        return record.didPoop ? "\(record.amount.emoji) \(record.amount.title)" : "😴 没拉"
    }

    private var subtitle: String {
        guard let record = day.record else {
            return "这一天还是空白小格子"
        }

        return record.didPoop ? "这天记录得很认真" : "小肚肚那天休息了一下"
    }

    private var detailBadge: some View {
        let color = Color.heatmapColor(for: day.record, colorScheme: .light)

        return RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(color.opacity(day.record == nil ? 0.24 : 1))
            .frame(width: 140, height: 140)
            .overlay {
                Text(day.record?.didPoop == true ? (day.record?.amount.emoji ?? "💩") : "🌙")
                    .font(.system(size: 58))
            }
            .shadow(color: color.opacity(0.28), radius: 18, y: 10)
    }
}

#Preview("Detail") {
    let day = HeatmapDay(
        id: Calendar.poopDiary.dayKey(for: .now),
        date: .now,
        record: PoopRecord(date: .now, didPoop: true, amount: .large)
    )
    RecordDetailSheet(day: day)
}
