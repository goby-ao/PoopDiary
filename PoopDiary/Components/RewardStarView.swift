import SwiftUI

struct RewardStarView: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(isActive ? Color.yellow : Color.gray.opacity(0.25))
            .symbolEffect(.bounce, value: isActive)
            .shadow(color: isActive ? .yellow.opacity(0.45) : .clear, radius: 12, y: 6)
            .accessibilityLabel(isActive ? "今日奖励星星已点亮" : "今日奖励星星未点亮")
    }
}

#Preview {
    HStack(spacing: 24) {
        RewardStarView(isActive: false)
        RewardStarView(isActive: true)
    }
    .padding()
}
