import SwiftUI

struct WelcomeView: View {
    let onSinglePlayer: () -> Void
    let onShowStats: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 34) {
                Spacer()

                VStack(spacing: 18) {
                    TileLogoView(text: "ALIGNERS", tileSize: 36, fontSize: 19, spacing: 6)
                    Text("Welcome to Aligners")
                        .font(Theme.archivoMedium(14))
                        .italic()
                        .foregroundColor(Theme.textMutedMid)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onSinglePlayer) {
                        Text("Single Player")
                            .font(Theme.archivoMedium(16))
                            .foregroundColor(Theme.ink)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onShowStats) {
                        Text("High Scores")
                            .font(Theme.archivoMedium(16))
                            .foregroundColor(Theme.textMutedDark)
                            .frame(maxWidth: 260)
                            .padding(.vertical, 15)
                            .background(Theme.textMutedDark.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.textMutedDark.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(24)
        }
    }
}
