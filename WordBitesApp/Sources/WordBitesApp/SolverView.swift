import SwiftUI

struct SolverView: View {
    let allWords: Set<String>
    let foundWords: Set<String>
    let score: Int
    let isComputing: Bool
    let onBack: () -> Void
    let onNewGame: () -> Void

    private var groupedWords: [(length: Int, words: [String])] {
        Dictionary(grouping: allWords, by: \.count)
            .sorted { $0.key < $1.key }
            .map { (length: $0.key, words: $0.value.sorted()) }
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0x2A5C4C), Theme.feltDeep],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 10,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                    Text("Solver")
                        .font(.custom("Georgia-Bold", size: 18))
                        .foregroundColor(Theme.cream)
                    Spacer()
                    Button(action: onNewGame) {
                        Text("New Game")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.woodDeep)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }

                Text("Final score: \(score)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.creamDim)

                if isComputing {
                    Spacer()
                    ProgressView("Finding every word...")
                        .tint(Theme.cream)
                        .foregroundColor(Theme.cream)
                    Spacer()
                } else if allWords.isEmpty {
                    Spacer()
                    Text("No valid words could be found on this board.")
                        .foregroundColor(Theme.creamDim)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(groupedWords, id: \.length) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(group.length) LETTERS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(1.2)
                                        .foregroundColor(Theme.creamDim)

                                    FlowLayout(spacing: 6) {
                                        ForEach(group.words, id: \.self) { word in
                                            wordChip(word)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .padding(18)
        }
    }

    private func wordChip(_ word: String) -> some View {
        let wasFound = foundWords.contains(word)
        return Text(word)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(wasFound ? Theme.woodDeep : Theme.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(wasFound ? Theme.accent : Color.white.opacity(0.1))
            .clipShape(Capsule())
    }
}
