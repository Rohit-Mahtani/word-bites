import SwiftUI

struct ModeSelectView: View {
    let onBack: () -> Void
    let onSelectMode: (GameMode) -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0x2A5C4C), Theme.feltDeep],
                center: .init(x: 0.5, y: 0.2),
                startRadius: 10,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                }
                Spacer()

                VStack(spacing: 28) {
                    Text("Choose a mode")
                        .font(.custom("Georgia-Bold", size: 22))
                        .foregroundColor(Theme.cream)

                    VStack(spacing: 14) {
                        modeButton(title: "Timed", subtitle: "80 seconds on the clock") { onSelectMode(.timed) }
                        modeButton(title: "Untimed", subtitle: "Play until you quit") { onSelectMode(.untimed) }
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(20)
        }
    }

    private func modeButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            .foregroundColor(Theme.woodDeep)
            .frame(maxWidth: 260)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// Shared top-left back arrow used here and on the solver screen.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.cream)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
    }
}
