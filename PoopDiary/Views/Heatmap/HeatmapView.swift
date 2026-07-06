import SwiftData
import SwiftUI

struct HeatmapView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \PoopRecord.date, order: .reverse) private var records: [PoopRecord]
    @State private var viewModel = HeatmapViewModel()
    @State private var selectedDay: HeatmapDay?
    @State private var mode: HeatmapMode = .month
    @State private var visibleMonth = Date()
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = "便便小超人"
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID

    private var profileRecords: [PoopRecord] {
        records.filter { $0.profileID == activeProfileID }
    }

    private var usesExpandedLayout: Bool {
        horizontalSizeClass == .regular
    }

    private var recentDayCount: Int {
        usesExpandedLayout ? 182 : 91
    }

    private var days: [HeatmapDay] {
        viewModel.recentDays(records: profileRecords, count: recentDayCount)
    }

    private var weeks: [[HeatmapDay?]] {
        let leadingBlankCount = (7 - days.count % 7) % 7
        let paddedDays = Array<HeatmapDay?>(repeating: nil, count: leadingBlankCount) + days.map(Optional.some)
        return stride(from: 0, to: paddedDays.count, by: 7).map { start in
            let end = min(start + 7, paddedDays.count)
            return Array(paddedDays[start..<end])
        }
    }

    private var monthDays: [HeatmapDay?] {
        viewModel.monthGrid(for: visibleMonth, records: profileRecords)
    }

    private var heatmapMetrics: HeatmapGridMetrics {
        usesExpandedLayout
            ? HeatmapGridMetrics(cellSize: 22, spacing: 6, padding: 20, cornerRadius: 26)
            : HeatmapGridMetrics(cellSize: 18, spacing: 7, padding: 18, cornerRadius: 26)
    }

    private var monthCellHeight: CGFloat {
        usesExpandedLayout ? 74 : 52
    }

    private var monthIconMaxSize: CGFloat {
        usesExpandedLayout ? 42 : 30
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .recent ? recentTitle : viewModel.monthTitle(for: visibleMonth))
                        .font(.system(size: 32, weight: .black, design: .rounded))

                    Text("\(ProfileStore.cleanNickname(childNickname))，每个小格子都是一天")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Picker("视图", selection: $mode) {
                    ForEach(HeatmapMode.allCases) { mode in
                        Text(title(for: mode)).tag(mode)
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
        let metrics = heatmapMetrics

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: metrics.spacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: metrics.spacing) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                HeatmapCell(
                                    day: day,
                                    color: Color.heatmapColor(for: day.record, colorScheme: colorScheme),
                                    size: metrics.cellSize,
                                    isToday: Calendar.poopDiary.isDateInToday(day.date)
                                ) {
                                    InteractionFeedback.play(sound: .tap, haptic: .light)
                                    selectedDay = day
                                }
                            } else {
                                Color.clear
                                    .frame(width: metrics.cellSize, height: metrics.cellSize)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(metrics.padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))

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

            let monthGridSpacing: CGFloat = usesExpandedLayout ? 12 : 8
            let columns = Array(repeating: GridItem(.flexible(), spacing: monthGridSpacing), count: 7)

            LazyVGrid(columns: columns, spacing: monthGridSpacing) {
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
                        height: monthCellHeight,
                        iconMaxSize: monthIconMaxSize,
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
        .simultaneousGesture(monthSwipeGesture)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                handleMonthSwipe(value)
            }
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
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            visibleMonth = Calendar.poopDiary.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        }
        InteractionFeedback.play(sound: .tap, haptic: .light)
    }

    private func handleMonthSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        let predictedHorizontal = value.predictedEndTranslation.width
        let threshold: CGFloat = 48

        // 只响应明确的横向滑动，避免影响月历格子的普通点击和上下滚动。
        guard abs(horizontal) > abs(vertical) * 1.35 else { return }
        guard abs(horizontal) > threshold || abs(predictedHorizontal) > threshold * 1.8 else { return }

        changeMonth(by: horizontal < 0 ? 1 : -1)
    }

    private func title(for mode: HeatmapMode) -> String {
        switch mode {
        case .recent:
            return usesExpandedLayout ? "半年" : "\(recentDayCount) 天"
        case .month:
            return "月历"
        }
    }

    private var recentTitle: String {
        usesExpandedLayout ? "最近半年" : "最近 \(recentDayCount) 天"
    }
}

private enum HeatmapMode: String, CaseIterable, Identifiable {
    case month
    case recent

    var id: String { rawValue }

}

private struct HeatmapGridMetrics {
    let cellSize: CGFloat
    let spacing: CGFloat
    let padding: CGFloat
    let cornerRadius: CGFloat
}

private struct HeatmapCell: View {
    let day: HeatmapDay
    let color: Color
    let size: CGFloat
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: max(6, size * 0.32), style: .continuous)
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
    let height: CGFloat
    let iconMaxSize: CGFloat
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
                    .frame(height: height)
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.poopAccent, lineWidth: 2)
                        }
                    }

                if let day {
                    Text(dayNumber(for: day.date))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(7)

                    if let record = day.record {
                        Group {
                            if record.didPoop {
                                PoopAmountMark(amount: record.amount, maxSize: iconMaxSize)
                            } else {
                                SleepyPoopMark(maxSize: iconMaxSize)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
                    }
                }
            }
            .opacity(isFuture ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(day == nil || isFuture)
        .accessibilityLabel(accessibilityText)
    }

    private var background: Color {
        guard let day else { return .clear }
        guard day.record != nil else { return Color(uiColor: .secondarySystemGroupedBackground) }
        return color
    }

    private func dayNumber(for date: Date) -> String {
        String(Calendar.poopDiary.component(.day, from: date))
    }

    private var accessibilityText: String {
        guard let day else { return "空白日期" }
        if let record = day.record {
            return "\(DateText.fullDate(day.date))，\(record.didPoop ? record.amount.title : "没拉")"
        }
        return "\(DateText.fullDate(day.date))，未打卡"
    }
}

private struct PoopAmountMark: View {
    let amount: PoopAmount
    let maxSize: CGFloat

    private var size: CGFloat {
        switch amount {
        case .none:
            return maxSize * 0.42
        case .small:
            return maxSize * 0.52
        case .normal:
            return maxSize * 0.84
        case .large:
            return maxSize * 1.12
        }
    }

    var body: some View {
        ZStack {
            poopBody
            face
                .offset(y: size * 0.08)
        }
        .frame(width: maxSize, height: maxSize)
        .shadow(color: .poopBrown.opacity(0.22), radius: size * 0.12, y: size * 0.07)
        .accessibilityHidden(true)
    }

    private var poopBody: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(bodyGradient)
                .frame(width: size * 0.88, height: size * 0.42)
                .offset(y: size * 0.12)

            Ellipse()
                .fill(bodyGradient)
                .frame(width: size * 0.68, height: size * 0.38)
                .offset(y: -size * 0.08)

            Ellipse()
                .fill(bodyGradient)
                .frame(width: size * 0.48, height: size * 0.32)
                .offset(y: -size * 0.26)

            Circle()
                .fill(bodyGradient)
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: size * 0.04, y: -size * 0.42)
        }
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [.poopBrownLight, .poopBrown],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var face: some View {
        VStack(spacing: size * 0.07) {
            eyes
            mouth
        }
    }

    private var eyes: some View {
        HStack(spacing: size * 0.18) {
            switch amount {
            case .large:
                ExcitedLaughEye(size: size * 0.15)
                ExcitedLaughEye(size: size * 0.15)
            default:
                Circle()
                    .fill(.black.opacity(0.82))
                    .frame(width: size * 0.11, height: size * 0.11)
                Circle()
                    .fill(.black.opacity(0.82))
                    .frame(width: size * 0.11, height: size * 0.11)
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch amount {
        case .small, .none:
            Capsule()
                .fill(.black.opacity(0.72))
                .frame(width: size * 0.24, height: max(2, size * 0.045))
        case .normal:
            MiniSmileArc()
                .stroke(.black.opacity(0.72), style: StrokeStyle(lineWidth: max(2, size * 0.08), lineCap: .round))
                .frame(width: size * 0.34, height: size * 0.18)
        case .large:
            Capsule()
                .fill(.black.opacity(0.75))
                .frame(width: size * 0.34, height: size * 0.24)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(.pink.opacity(0.9))
                        .frame(width: size * 0.18, height: size * 0.10)
                        .padding(.bottom, size * 0.02)
                }
        }
    }
}

private struct SleepyPoopMark: View {
    let maxSize: CGFloat

    private var size: CGFloat {
        maxSize * 0.54
    }

    var body: some View {
        ZStack {
            sleepyBody
            sleepyFace
                .offset(y: size * 0.08)

            SleepyZTrail(size: size)
                .offset(x: size * 0.60, y: -size * 0.58)
        }
        .frame(width: maxSize, height: maxSize)
        .opacity(0.9)
        .accessibilityHidden(true)
    }

    private var sleepyBody: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(sleepyGradient)
                .frame(width: size * 0.88, height: size * 0.42)
                .offset(y: size * 0.12)

            Ellipse()
                .fill(sleepyGradient)
                .frame(width: size * 0.68, height: size * 0.38)
                .offset(y: -size * 0.08)

            Ellipse()
                .fill(sleepyGradient)
                .frame(width: size * 0.48, height: size * 0.32)
                .offset(y: -size * 0.26)

            Circle()
                .fill(sleepyGradient)
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: size * 0.04, y: -size * 0.42)
        }
    }

    private var sleepyGradient: LinearGradient {
        LinearGradient(
            colors: [.poopBrownLight.opacity(0.58), .poopBrown.opacity(0.46)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sleepyFace: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.18) {
                Capsule()
                    .fill(.black.opacity(0.44))
                    .frame(width: size * 0.13, height: max(1.5, size * 0.035))
                Capsule()
                    .fill(.black.opacity(0.44))
                    .frame(width: size * 0.13, height: max(1.5, size * 0.035))
            }

            Capsule()
                .fill(.black.opacity(0.4))
                .frame(width: size * 0.20, height: max(1.5, size * 0.035))
        }
    }
}

private struct SleepyZTrail: View {
    let size: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: size * 0.02) {
            ForEach(0..<3, id: \.self) { index in
                Text("Z")
                    .font(.system(size: zSize(for: index), weight: .black, design: .rounded))
                    .foregroundStyle(Color.poopBrown.opacity(0.52 + Double(index) * 0.08))
                    .offset(y: -CGFloat(index) * size * 0.08)
            }
        }
        .rotationEffect(.degrees(-18))
    }

    private func zSize(for index: Int) -> CGFloat {
        size * (0.20 + CGFloat(index) * 0.08)
    }
}

private struct ExcitedLaughEye: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(.black.opacity(0.82))
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: max(2, size * 0.34), height: max(2, size * 0.34))
                    .offset(x: size * 0.18, y: size * 0.18)
            }
            .overlay(alignment: .top) {
                DownturnedLaughBrow()
                    .stroke(.black.opacity(0.62), style: StrokeStyle(lineWidth: max(1.4, size * 0.18), lineCap: .round))
                    .frame(width: size * 1.14, height: size * 0.46)
                    .offset(y: -size * 0.58)
            }
    }
}

private struct DownturnedLaughBrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.82))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.82),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

private struct MiniSmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(24),
            endAngle: .degrees(156),
            clockwise: false
        )
        return path
    }
}

#Preview("Heatmap") {
    NavigationStack {
        HeatmapView()
    }
    .modelContainer(SampleData.previewContainer())
}
