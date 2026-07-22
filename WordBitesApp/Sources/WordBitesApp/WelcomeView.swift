import SwiftUI

struct WelcomeView: View {
    let onSinglePlayer: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0x2A5C4C), Theme.feltDeep],
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
                        .foregroundColor(Theme.creamDim)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onSinglePlayer) {
                        Text("Single Player")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.woodDeep)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                            )
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
