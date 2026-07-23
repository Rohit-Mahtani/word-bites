import SwiftUI

struct WelcomeView: View {
    let onSinglePlayer: () -> Void
    let onShowStats: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.pageGlow, Theme.pageDeep],
                center: .init(x: 0.5, y: 0.2),
                startRadius: 10,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 34) {
                Spacer()

                VStack(spacing: 18) {
                    TileLogoView(text: "WORD BITES", tileSize: 40, fontSize: 24, spacing: 6)
                    Text("Welcome to Word Bites")
                        .font(.custom("Georgia", size: 16))
                        .foregroundColor(Theme.pageTextDim)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onSinglePlayer) {
                        Text("Single Player")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.chromeText)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: onShowStats) {
                        Text("High Scores")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.pageText)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(24)
        }
    }
}
