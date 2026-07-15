import Charts
import SwiftData
import SwiftUI
import UIKit

struct StatsView: View {
    @Query(sort: \PoopRecord.date, order: .reverse) private var records: [PoopRecord]
    @State private var viewModel = StatsViewModel()
    @State private var reportURL: URL?
    @State private var exportMessage: String?
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = "便便小超人"
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID

    private var profileRecords: [PoopRecord] {
        records.filter { $0.profileID == activeProfileID }
    }

    private var longestPoopStreak: Int {
        viewModel.longestPoopStreak(records: profileRecords)
    }

    private var recentStats: [DailyCheckInStat] {
        viewModel.recentCheckInStats(records: profileRecords)
    }

    private var recentSevenDaySummary: String {
        let poopDays = recentStats.filter(\.didPoop).count
        let restDays = recentStats.filter { $0.hasRecord && !$0.didPoop }.count
        let missingDays = recentStats.filter { !$0.hasRecord }.count

        if missingDays == 0 {
            return "拉了 \(poopDays) 天，没拉 \(restDays) 天"
        }

        return "拉了 \(poopDays) 天，没拉 \(restDays) 天，未记录 \(missingDays) 天"
    }

    private var distribution: [AmountDistributionSlice] {
        viewModel.amountDistribution(records: profileRecords)
    }

    private var trendPoints: [TrendPoint] {
        viewModel.trendPoints(records: profileRecords)
    }

    private var report: MonthlyReport {
        viewModel.monthlyReport(records: profileRecords)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                summaryGrid
                recentSevenDayChart
                distributionChart
                trendChart
                monthProgress
                healthTip
                AchievementWallView(records: profileRecords, profileID: activeProfileID)
                monthlyReportSection
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("数据")
        .navigationBarTitleDisplayMode(.inline)
        .alert("导出结果", isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("好") { exportMessage = nil }
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("趣味数据")
                .font(.system(size: 32, weight: .black, design: .rounded))

            Text("\(ProfileStore.cleanNickname(childNickname))，\(longestPoopMessage)")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(title: "最长连续拉粑粑", value: "\(longestPoopStreak)", systemImage: "flame.fill", tint: .orange) {
                Text("天 · 历史最佳")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            StatCard(title: "日均拉粑粑", value: String(format: "%.1f", viewModel.averagePoopPerDay(records: profileRecords)), systemImage: "divide.circle.fill", tint: .poopAccent) {
                Text("近 30 天平均")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            StatCard(title: "正常量占比", value: "\(Int((viewModel.regularityRate(records: profileRecords) * 100).rounded()))%", systemImage: "checkmark.seal.fill", tint: .mint) {
                Text("近 30 天正常量")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            StatCard(title: "最爱星期", value: viewModel.favoriteWeekday(records: profileRecords), systemImage: "calendar.circle.fill", tint: .pink) {
                Text("拉了最多的一天")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recentSevenDayChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label("最近 7 天拉粑粑", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(recentSevenDaySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Chart(recentStats) { stat in
                BarMark(
                    x: .value("日期", DateText.weekdayShort(stat.date)),
                    y: .value("拉粑粑", stat.didPoop ? 1 : 0)
                )
                .foregroundStyle(stat.didPoop ? Color.poopAccent.gradient : Color.gray.opacity(0.16).gradient)
                .cornerRadius(8)

                PointMark(
                    x: .value("日期", DateText.weekdayShort(stat.date)),
                    y: .value("状态", stat.didPoop ? 1 : 0)
                )
                .foregroundStyle(recentStatColor(stat))
                .symbolSize(stat.hasRecord ? 64 : 34)
                .annotation(position: stat.didPoop ? .top : .bottom) {
                    Text(stat.statusEmoji)
                        .font(.caption)
                        .opacity(stat.hasRecord ? 1 : 0.5)
                }
            }
            .chartYScale(domain: -0.14...1.18)
            .chartYAxis(.hidden)
            .frame(height: 160)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("最近 30 天量分布", systemImage: "chart.pie.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            if distribution.map(\.count).reduce(0, +) == 0 {
                Text("还没有可统计的量，等第一次打卡吧")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(distribution.filter { $0.count > 0 }) { slice in
                    SectorMark(
                        angle: .value("次数", slice.count),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("量", slice.title))
                    .annotation(position: .overlay) {
                        if slice.count > 0 {
                            Text(slice.amount.emoji)
                                .font(.title3)
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "少量": Color.poopLightGreen,
                    "正常": Color.poopMediumGreen,
                    "很多": Color.poopDeepGreen
                ])
                .frame(height: 220)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("最近 30 天趋势", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(.secondary)

            Chart(trendPoints) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("分数", point.score)
                )
                .foregroundStyle(Color.poopAccent.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("日期", point.date),
                    y: .value("分数", point.score)
                )
                .foregroundStyle(Color.poopAccent.opacity(0.16).gradient)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...3)
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let score = value.as(Int.self) {
                            Text(scoreTitle(score))
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var monthProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("本月里程碑", systemImage: "flag.checkered.circle.fill")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.currentMonthPoopCount(records: profileRecords))/20")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.monthlyProgress(records: profileRecords))
                .tint(.poopAccent)

            Text("先冲 20 次小目标，完成就很闪亮")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var healthTip: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.title2)
                .foregroundStyle(.cyan)

            Text(viewModel.healthTip(records: profileRecords))
                .font(.headline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var monthlyReportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("月度便便小报告", systemImage: "square.and.arrow.up.fill")
                .font(.headline)

            MonthlyReportCardView(report: report, nickname: ProfileStore.cleanNickname(childNickname))
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button {
                    exportReportImage()
                } label: {
                    Label("生成图片", systemImage: "photo.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.poopAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                if let reportURL {
                    ShareLink(item: reportURL) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var longestPoopMessage: String {
        switch longestPoopStreak {
        case 0:
            return "先记录一次拉粑粑，小火苗就会亮起来"
        case 1:
            return "最长连续 1 天，开始点亮小火苗"
        case 2..<7:
            return "最长连续 \(longestPoopStreak) 天，节奏开始成形"
        default:
            return "最长连续 \(longestPoopStreak) 天，习惯很稳"
        }
    }

    private func recentStatColor(_ stat: DailyCheckInStat) -> Color {
        if stat.didPoop {
            return .poopAccent
        }

        return stat.hasRecord ? .mint : .gray.opacity(0.35)
    }

    private func scoreTitle(_ score: Int) -> String {
        switch score {
        case 0:
            "0"
        case 1:
            "少"
        case 2:
            "正常"
        default:
            "多"
        }
    }

    @MainActor
    private func exportReportImage() {
        let card = MonthlyReportCardView(report: report, nickname: ProfileStore.cleanNickname(childNickname))
            .frame(width: 360, height: 520)
            .padding(18)
            .background(Color.poopCream)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage, let data = image.pngData() else {
            exportMessage = "图片生成失败，请再试一次"
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory.appending(path: "PoopDiary-\(report.monthTitle)-Report.png")
            try data.write(to: url, options: [.atomic])
            reportURL = url
            exportMessage = "月报图片已生成，可以点击分享"
            InteractionFeedback.reward()
        } catch {
            exportMessage = "图片保存失败，请再试一次"
        }
    }
}

struct MonthlyReportCardView: View {
    let report: MonthlyReport
    let nickname: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(report.monthTitle)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("\(nickname) 的便便小报告")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("💩")
                    .font(.system(size: 46))
            }

            HStack(spacing: 12) {
                reportMetric(title: "总次数", value: "\(report.totalPoopCount)")
                reportMetric(title: "最规律", value: report.bestWeekTitle)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("各量占比")
                    .font(.headline)

                amountRow(title: "少量", count: report.smallCount, color: .poopLightGreen)
                amountRow(title: "正常", count: report.normalCount, color: .poopMediumGreen)
                amountRow(title: "很多", count: report.largeCount, color: .poopDeepGreen)
            }

            Text("拉了或没拉，都值得被温柔记录。")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.92), Color.poopPrimary.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.poopAccent.opacity(0.24), lineWidth: 2)
        }
    }

    private func reportMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func amountRow(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(width: 46, alignment: .leading)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .frame(width: max(CGFloat(report.percent(for: count)) / 100 * proxy.size.width, count > 0 ? 12 : 0))
            }
            .frame(height: 14)

            Text("\(report.percent(for: count))%")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

#Preview("Stats") {
    NavigationStack {
        StatsView()
    }
    .modelContainer(SampleData.previewContainer())
}
