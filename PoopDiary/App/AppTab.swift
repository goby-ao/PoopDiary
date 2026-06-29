import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case heatmap
    case stats

    var id: String { rawValue }

    @ViewBuilder
    var label: some View {
        switch self {
        case .today:
            Label("今日", systemImage: "checkmark.circle.fill")
        case .heatmap:
            Label("热力图", systemImage: "calendar")
        case .stats:
            Label("数据", systemImage: "chart.bar.fill")
        }
    }
}
