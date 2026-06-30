import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppPreferenceKey.childNickname) private var childNickname = ""
    @AppStorage(AppPreferenceKey.activeProfileID) private var activeProfileID = ProfileStore.defaultProfileID
    @AppStorage(AppPreferenceKey.profilesJSON) private var profilesJSON = ""
    @State private var draftNickname = ""

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 24)

            PoopMascotView(mood: .happy, bounceTrigger: UUID())
                .frame(height: 230)

            VStack(spacing: 10) {
                Text("先给小朋友取个昵称")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("以后每次打卡，便便超人都会这样叫你")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("比如：便便小超人", text: $draftNickname)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("随机萌名")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 10) {
                    ForEach(ProfileStore.nicknameSuggestions, id: \.self) { nickname in
                        Button {
                            draftNickname = nickname
                            InteractionFeedback.play(sound: .tap, haptic: .light)
                        } label: {
                            Text(nickname)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.poopPrimary.opacity(0.18), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                saveProfile()
            } label: {
                Label("开始打卡", systemImage: "star.fill")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.poopAccent, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .foregroundStyle(.white)
                    .shadow(color: Color.poopAccent.opacity(0.26), radius: 16, y: 8)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 16)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.poopPrimary.opacity(0.22), Color(uiColor: .systemBackground), Color.poopCream.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            if draftNickname.isEmpty {
                draftNickname = ProfileStore.nicknameSuggestions.randomElement() ?? "便便小超人"
            }
        }
    }

    private func saveProfile() {
        let nickname = ProfileStore.cleanNickname(draftNickname)
        let profile = ChildProfile(nickname: nickname)
        let profiles = ProfileStore.upsertProfile(profile, in: ProfileStore.profiles(from: profilesJSON))

        profilesJSON = ProfileStore.encodedProfiles(profiles)
        activeProfileID = profile.id
        childNickname = profile.nickname
        InteractionFeedback.reward()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(width: size.width, height: size.height))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
}
