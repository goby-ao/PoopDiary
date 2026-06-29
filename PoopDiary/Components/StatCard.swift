import SwiftUI

struct StatCard<Content: View>: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var content: Content

    init(
        title: String,
        value: String,
        systemImage: String,
        tint: Color = .poopAccent,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())

            content
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

#Preview {
    StatCard(title: "连续打卡", value: "7 天", systemImage: "flame.fill") {
        Text("闪闪发光的一周")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color.poopCream)
}
