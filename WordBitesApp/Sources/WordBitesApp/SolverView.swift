import SwiftUI
import WordBitesKit

struct SolverView: View {
    let allWords: Set<String>
    let foundWords: Set<String>
    let score: Int
    let isComputing: Bool
    let arrangementProvider: (String) -> WordArrangement?
    let onBack: () -> Void
    let onNewGame: () -> Void

    @State private var selectedWord: String?
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var screenSize: CGSize = .zero

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
                    Text("Words found: \(foundWords.count)")
                        .font(Theme.archivoSemiBold(14))
                        .foregroundColor(Theme.ink.opacity(0.75))
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

            if let selectedWord, let frame = chipFrames[selectedWord] {
                WordArrangementPopup(
                    word: selectedWord,
                    arrangement: arrangementProvider(selectedWord),
                    onDismiss: { self.selectedWord = nil }
                )
                .position(popupPosition(for: frame, wordLength: selectedWord.count))
            }
        }
        .coordinateSpace(name: "solver")
        .onPreferenceChange(WordChipFramePreferenceKey.self) { chipFrames = $0 }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear { screenSize = geometry.size }
                    .onChange(of: geometry.size) { screenSize = $0 }
            }
        )
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
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: WordChipFramePreferenceKey.self,
                        value: [word: geometry.frame(in: .named("solver"))]
                    )
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                FeedbackPlayer.buttonTapped()
                selectedWord = (selectedWord == word) ? nil : word
            }
    }

    /// Centers the popup beside the tapped chip: below it if there's room,
    /// above it otherwise, horizontally clamped so it never runs off
    /// either edge of the screen. The height/width used for clamping are
    /// estimates (the popup's real size depends on the word's own tile
    /// count) -- close enough since this only affects how well-centered the
    /// popup looks, not whether it stays on screen or is dismissible.
    private func popupPosition(for frame: CGRect, wordLength: Int) -> CGPoint {
        let estimatedHeight = CGFloat(max(wordLength, 3)) * 33 + 66
        let estimatedWidth: CGFloat = 150
        let placeBelow = frame.midY < screenSize.height * 0.6
        let rawY = placeBelow
            ? frame.maxY + estimatedHeight / 2 + 10
            : frame.minY - estimatedHeight / 2 - 10
        let halfWidth = estimatedWidth / 2
        let x = screenSize.width > 0
            ? min(max(frame.midX, halfWidth + 12), screenSize.width - halfWidth - 12)
            : frame.midX
        let y = max(rawY, estimatedHeight / 2 + 12)
        return CGPoint(x: x, y: y)
    }
}

private struct WordChipFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Groups a word's raw `WordArrangementSlot`s into renderable rows: a
/// `doubleInline` pair (a double tile aligned with the word's own reading
/// direction) always arrives as two consecutive slots and is rendered as
/// one fused two-cell tile; everything else is already one row.
private enum ArrangementRow {
    case single(Character)
    case perpendicularDouble(used: Character, other: Character, usedIsFirst: Bool)
    case inlineDouble(first: Character, second: Character)
}

private func arrangementRows(for arrangement: WordArrangement) -> [ArrangementRow] {
    var rows: [ArrangementRow] = []
    var i = 0
    let slots = arrangement.slots
    while i < slots.count {
        switch slots[i] {
        case .single(let letter):
            rows.append(.single(letter))
            i += 1
        case .doublePerpendicular(let used, let other, let usedIsFirst):
            rows.append(.perpendicularDouble(used: used, other: other, usedIsFirst: usedIsFirst))
            i += 1
        case .doubleInline(let letter, let isFirstOfPair):
            if isFirstOfPair, i + 1 < slots.count, case .doubleInline(let second, false) = slots[i + 1] {
                rows.append(.inlineDouble(first: letter, second: second))
                i += 2
            } else {
                // Defensive fallback for a lone/mismatched inline slot --
                // shouldn't happen given how WordFinder always emits an
                // inline pair together, but avoids ever silently dropping
                // a letter from the display.
                rows.append(.single(letter))
                i += 1
            }
        }
    }
    return rows
}

/// One tile-shaped row in the arrangement popup: a single letter, a
/// perpendicular double tile (both its letters shown side by side, the
/// unused one dimmed since it's not actually part of the word but is still
/// physically fused to the tile that is), or an inline double tile spanning
/// two stacked cells.
private struct ArrangementRowView: View {
    let row: ArrangementRow
    private let cellSize: CGFloat = 30

    var body: some View {
        content
            .background(TileBackground())
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.tileBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var content: some View {
        switch row {
        case .single(let letter):
            cell(String(letter), dimmed: false)
                .frame(width: cellSize, height: cellSize)
        case .perpendicularDouble(let used, let other, let usedIsFirst):
            HStack(spacing: 0) {
                cell(String(usedIsFirst ? used : other), dimmed: !usedIsFirst)
                cell(String(usedIsFirst ? other : used), dimmed: usedIsFirst)
            }
            .frame(width: cellSize * 2, height: cellSize)
        case .inlineDouble(let first, let second):
            VStack(spacing: 0) {
                cell(String(first), dimmed: false)
                cell(String(second), dimmed: false)
            }
            .frame(width: cellSize, height: cellSize * 2)
        }
    }

    private func cell(_ text: String, dimmed: Bool) -> some View {
        Text(text)
            .font(Theme.archivoMedium(cellSize * 0.45))
            .foregroundColor(dimmed ? Theme.inkBoard.opacity(0.35) : Theme.inkBoard)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when a solver word is tapped: the physical tiles (in reading
/// order, top to bottom) that would spell it, reusing the game's own tile
/// styling. Dismissible via the "x" in its corner.
private struct WordArrangementPopup: View {
    let word: String
    let arrangement: WordArrangement?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(word)
                    .font(Theme.archivoSemiBold(14))
                    .foregroundColor(Theme.ink)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textMutedDark)
                        .frame(width: 22, height: 22)
                        .background(Theme.textMutedDark.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            if let arrangement {
                VStack(spacing: 2) {
                    ForEach(Array(arrangementRows(for: arrangement).enumerated()), id: \.offset) { _, row in
                        ArrangementRowView(row: row)
                    }
                }
            } else {
                Text("Couldn't reconstruct an arrangement for this word.")
                    .font(Theme.archivoMedium(11))
                    .foregroundColor(Theme.textMutedLight)
                    .frame(width: 140)
            }
        }
        .padding(12)
        .background(Theme.pageTop)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.textMutedDark.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}
