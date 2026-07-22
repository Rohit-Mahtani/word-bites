import SwiftUI

struct RoundEndOverlay: View {
    let score: Int
    let words: [(word: String, points: Int)]
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Time's up!")
                    .font(.custom("Georgia-Bold", size: 26))
                    .foregroundColor(Theme.cream)

                Text("\(score)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Theme.accent)

                Text(words.isEmpty ? "No words found this round." : "Found: " + words.map(\.word).joined(separator: ", "))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.creamDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                Button(action: onPlayAgain) {
                    Text("Play again")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.woodDeep)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(28)
            .background(
                LinearGradient(colors: [Theme.woodLight, Theme.woodDeep], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(32)
        }
    }
}
