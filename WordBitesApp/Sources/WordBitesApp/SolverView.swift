import SwiftUI
import WordBitesKit

struct SolverView: View {
    let allWords: Set<String>
    let foundWords: Set<String>
    let score: Int
    let isComputing: Bool
    let onBack: () -> Void
    let onNewGame: () -> Void

    private var groupedWords: [(length: Int, words: [String])] {
        Dictionary(grouping: allWords, by: \.count)
            .sorted { $0.key > $1.key }
            .map { (length: $0.key, words: $0.value.sorted()) }
    }

    private var totalPossiblePoints: Int {
        allWords.compactMap(Scorer.points(for:)).reduce(0, +)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                // Back button and the "+" button are the same fixed 36pt
                // circle, so the Spacers on either side of the title get
                // equal weight and it lands truly centered -- a wide
                // "New Game" text button here previously threw that off.
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                    Text("Solver")
                        .font(Theme.archivoBold(26))
                        .foregroundColor(Theme.ink)
                    Spacer()
                    Button(action: onNewGame) {
                        Text("+")
                            .font(Theme.archivoBold(20))
                            .foregroundColor(Theme.ink)
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(Circle())
                    }
                }

                VStack(spacing: 4) {
                    Text("Final score: \(score)")
                        .font(Theme.archivoSemiBold(16))
                        .foregroundColor(Theme.ink)
                    if !isComputing, !allWords.isEmpty {
                        Text("You found \(score) of \(totalPossiblePoints) possible points")
                            .font(Theme.archivoMedium(12))
                            .foregroundColor(Theme.textMutedLight)
                    }
                }

                if isComputing {
                    Spacer()
                    ProgressView("Finding every word...")
                        .tint(Theme.ink)
                        .foregroundColor(Theme.ink)
                    Spacer()
                } else if allWords.isEmpty {
                    Spacer()
                    Text("No valid words could be found on this board.")
                        .foregroundColor(Theme.textMutedMid)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(groupedWords, id: \.length) { group in
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack(alignment: .lastTextBaseline) {
                                        Text("\(group.length) Letters")
                                            .font(Theme.archivoSemiBold(13))
                                            .foregroundColor(Theme.ink)
                                        Spacer()
                                        Text("\(group.words.count) words")
                                            .font(Theme.archivoMedium(11))
                                            .foregroundColor(Theme.textMutedLight)
                                    }

                                    FlowLayout(spacing: 6) {
                                        ForEach(group.words, id: \.self) { word in
                                            wordChip(word)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Theme.cardTranslucent)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
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
            .font(Theme.archivoMedium(12))
            .foregroundColor(wasFound ? Theme.ink : Theme.textMutedDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(wasFound ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color(hex: 0xF0E4CC)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
