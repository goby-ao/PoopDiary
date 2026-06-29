import SwiftData
import SwiftUI

struct HeatmapView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \PoopRecord.date, order: .reverse) private var records: [PoopRecord]
    @State private var viewModel = HeatmapViewModel()
    @State private var selectedDay: HeatmapDay?
    @State private var mode: HeatmapMode = .recent
    @State private var visibleMonth = Date()
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = "便便小超人"
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID

    private var profileRecords: [PoopRecord] {
        records.filter { $0.profileID == activeProfileID }
    }

    private var days: [HeatmapDay] {
        viewModel.recentDays(records: profileRecords)
    }

    private var weeks: [[HeatmapDay]] {
        viewModel.weeks(from: days)
    }

    private var monthDays: [HeatmapDay?] {
        viewModel.monthGrid(for: visibleMonth, records: profileRecords)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .recent ? "最近 91 天" : viewModel.monthTitle(for: visibleMonth))
                        .font(.system(size: 32, weight: .black, design: .rounded))

                    Text("\(ProfileStore.cleanNickname(childNickname))，每个小格子都是一天")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Picker("视图", selection: $mode) {
                    ForEach(HeatmapMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .recent {
                    heatmapGrid
                } else {
                    monthCalendar
                }

                legend
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("热力图")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { day in
            RecordEntrySheet(day: day, profileID: activeProfileID)
                .presentationDetents([.medium])
        }
    }

    private var heatmapGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 7) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 7) {
                        ForEach(week) { day in
                            HeatmapCell(
                                day: day,
                                color: Color.heatmapColor(for: day.record, colorScheme: colorScheme),
                                isToday: Calendar.poopDiary.isDateInToday(day.date)
                            ) {
                                InteractionFeedback.play(sound: .tap, haptic: .light)
                                selectedDay = day
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            HStack {
                Text(DateText.monthDay(days.first?.date ?? .now))
                Spacer()
                Text(DateText.monthDay(days.last?.date ?? .now))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("少")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(PoopAmount.checkInChoices) { amount in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(legendColor(for: amount))
                    .frame(width: 24, height: 24)
                    .accessibilityLabel(amount.title)
            }

            Text("多")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var monthCalendar: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("上个月")

                Spacer()

                Text(viewModel.monthTitle(for: visibleMonth))
                    .font(.system(.headline, design: .rounded).weight(.black))

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("下个月")
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    MonthCalendarCell(
                        day: day,
                        color: Color.heatmapColor(for: day?.record, colorScheme: colorScheme),
                        isToday: day.map { Calendar.poopDiary.isDateInToday($0.date) } ?? false,
                        isFuture: day.map { $0.date > Date() } ?? false
                    ) {
                        guard let day, day.date <= Date() else { return }
                        InteractionFeedback.play(sound: .tap, haptic: .light)
                        selectedDay = day
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func legendColor(for amount: PoopAmount) -> Color {
        switch amount {
        case .none:
            return colorScheme == .dark ? .white.opacity(0.16) : .gray.opacity(0.22)
        case .small:
            return .poopLightGreen
        case .normal:
            return .poopMediumGreen
        case .large:
            return .poopDeepGreen
        }
    }

    private func changeMonth(by value: Int) {
        visibleMonth = Calendar.poopDiary.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        InteractionFeedback.play(sound: .tap, haptic: .light)
    }
}

private enum HeatmapMode: String, CaseIterable, Identifiable {
    case recent
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            "91 天"
        case .month:
            "月历"
        }
    }
}

private struct HeatmapCell: View {
    let day: HeatmapDay
    let color: Color
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.poopAccent, lineWidth: 2)
                    }
                }
                .shadow(color: day.record?.didPoop == true ? color.opacity(0.32) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let record = day.record {
            return "\(DateText.fullDate(day.date))，\(record.didPoop ? record.amount.title : "没拉")"
        }

        return "\(DateText.fullDate(day.date))，未打卡"
    }
}

private struct MonthCalendarCell: View {
    let day: HeatmapDay?
    let color: Color
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
                    .frame(height: 52)
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.poopAccent, lineWidth: 2)
                        }
                    }

                if let day {
                    VStack(spacing: 2) {
                        Text(dayNumber(for: day.date))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let record = day.record {
                            Text(record.didPoop ? "💩" : "😴")
                                .font(.system(size: 19))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(7)
                }
            }
            .opacity(isFuture ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(day == nil || isFuture)
    }

    private var background: Color {
        guard let day else { return .clear }
        guard day.record != nil else { return Color(uiColor: .secondarySystemGroupedBackground) }
        return color
    }

    private func dayNumber(for date: Date) -> String {
        String(Calendar.poopDiary.component(.day, from: date))
    }
}

#Preview("Heatmap") {
    NavigationStack {
        HeatmapView()
    }
    .modelContainer(SampleData.previewContainer())
}
