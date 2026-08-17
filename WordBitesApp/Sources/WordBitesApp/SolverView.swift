import SwiftUI
import UIKit
import WordBitesKit

/// Observes the word list's enclosing `UIScrollView` directly via KVO on
/// its `contentOffset`, instead of SwiftUI's `GeometryReader` +
/// `PreferenceKey` -- that pattern has now failed 4 times in this app for
/// tracking a live scroll position (toast positioning, HUD/board gap
/// measurement, and two separate attempts at this exact scrubber sync, the
/// most recent confirmed on-device to just never update: the thumb stayed
/// snapped to its initial computed value the whole time, which is why it
/// "shot back" the instant a scrubber-driven scroll ended and the
/// (frozen) external value took back over. GeometryReader/PreferenceKey
/// inside a `ScrollView`'s own scrolling content is being treated as a
/// dead end in this app now, not retried a fifth time.
///
/// KVO on `contentOffset` is a plain UIKit mechanism, not a SwiftUI-internal
/// one, and doesn't touch the scroll view's delegate -- it coexists safely
/// with whatever SwiftUI itself already set as the delegate. It also picks
/// up `scrollProxy.scrollTo(...)`-driven scrolls the same as a real
/// touch-scroll, since both ultimately move the same `contentOffset`.
private struct ScrollFractionObserver: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        // Deferred one runloop tick so the view is actually inserted into
        // its window/superview chain before searching it -- at
        // `makeUIView` time itself, that chain isn't guaranteed complete.
        DispatchQueue.main.async {
            context.coordinator.attach(startingFrom: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject {
        private let onChange: (CGFloat) -> Void
        private var observation: NSKeyValueObservation?

        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
        }

        func attach(startingFrom view: UIView) {
            guard observation == nil, let scrollView = Self.findEnclosingScrollView(from: view) else { return }
            observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in
                let scrollableRange = scrollView.contentSize.height - scrollView.bounds.height
                guard scrollableRange > 0 else {
                    self?.onChange(0)
                    return
                }
                let fraction = scrollView.contentOffset.y / scrollableRange
                self?.onChange(min(1, max(0, fraction)))
            }
        }

        private static func findEnclosingScrollView(from view: UIView) -> UIScrollView? {
            var current = view.superview
            while let candidate = current {
                if let scrollView = candidate as? UIScrollView { return scrollView }
                current = candidate.superview
            }
            return nil
        }
    }
}

/// Holds the word list's live scroll fraction as a small, isolated
/// reference type, observed only by `WordListScrubber` -- not by
/// `SolverView` itself. `SolverView`'s body rebuilds `groupedWords` and
/// `flatWords` (an uncached `Dictionary` grouping + sort over every solver
/// word) on every invocation; if `SolverView` held this via `@StateObject`/
/// `@ObservedObject`, that whole rebuild would re-run on every single
/// scroll frame the `ScrollFractionObserver` reports (up to 60-120Hz),
/// which is exactly what made scrolling choppy. `SolverView` instead holds
/// this via plain `@State` -- enough to keep one stable instance alive
/// across `SolverView`'s own re-renders, without subscribing to its
/// `@Published` changes -- and only passes the reference down;
/// `WordListScrubber` is the one place that actually observes it, so only
/// its own (cheap) body re-runs per scroll frame.
private final class ScrollFractionModel: ObservableObject {
    @Published var fraction: CGFloat = 0
}

struct SolverView: View {
    let allWords: Set<String>
    let foundWords: Set<String>
    let score: Int
    let isComputing: Bool
    let arrangementProvider: (String) -> WordArrangement?
    let onBack: () -> Void
    let onNewGame: () -> Void

    @State private var selectedWord: String?
    @State private var screenSize: CGSize = .zero

    // Tracks the word list's live scroll position, via ScrollFractionObserver
    // above, so the scrubber's thumb also moves when the list is scrolled
    // the normal way, by swiping it directly. See ScrollFractionModel's
    // doc comment for why this is plain @State holding a reference, not
    // @StateObject.
    @State private var scrollFractionModel = ScrollFractionModel()

    private var groupedWords: [(length: Int, words: [String])] {
        Dictionary(grouping: allWords, by: \.count)
            .sorted { $0.key > $1.key }
            .map { (length: $0.key, words: $0.value.sorted()) }
    }

    /// Every word in the same top-to-bottom, left-to-right order they're
    /// actually rendered in -- lets the scrubber jump to individual words
    /// (fine-grained, feels continuous) instead of just the 6-7 length
    /// groups (coarse, feels like jumping between sections).
    private var flatWords: [String] {
        groupedWords.flatMap { $0.words }
    }

    /// Where (0...1 along the flattened word list) each length group
    /// begins, for the scrubber's tick marks.
    private var groupStartFractions: [CGFloat] {
        guard !flatWords.isEmpty else { return [] }
        var fractions: [CGFloat] = []
        var runningCount = 0
        for group in groupedWords {
            fractions.append(CGFloat(runningCount) / CGFloat(flatWords.count))
            runningCount += group.words.count
        }
        return fractions
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
                    ScrollViewReader { scrollProxy in
                        ZStack(alignment: .trailing) {
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
                                                        .id(word)
                                                }
                                            }
                                        }
                                        .padding(14)
                                        .background(Theme.cardTranslucent)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                                .padding(.bottom, 20)
                                .padding(.trailing, flatWords.count > 1 ? 8 : 0)
                                .background(
                                    ScrollFractionObserver { fraction in
                                        // Mutates a @Published property on a
                                        // reference SolverView itself only
                                        // holds via plain @State (see
                                        // ScrollFractionModel's doc comment)
                                        // -- this does NOT invalidate
                                        // SolverView's own body.
                                        scrollFractionModel.fraction = fraction
                                    }
                                )
                            }
                            .scrollIndicators(.hidden)

                            // Replaces the native scroll indicator entirely
                            // (hidden above) with one draggable track. Maps
                            // the drag to an individual WORD, not just the
                            // 6-7 length groups -- jumping between only 6-7
                            // stops read as discontinuous "teleporting"
                            // rather than a smooth scroll; with 50-100+
                            // words as stops instead, dragging tracks the
                            // list continuously, the way swiping does.
                            //
                            // The thumb also reflects the list's position
                            // when it's scrolled the normal way (swiping),
                            // via scrollFractionModel, kept live by
                            // ScrollFractionObserver above.
                            if flatWords.count > 1 {
                                WordListScrubber(tickFractions: groupStartFractions, model: scrollFractionModel) { fraction in
                                    let index = min(flatWords.count - 1, Int(fraction * CGFloat(flatWords.count)))
                                    let anchor: UnitPoint = fraction > 0.98 ? .bottom : .top
                                    scrollProxy.scrollTo(flatWords[index], anchor: anchor)
                                }
                                .frame(width: 10)
                            }
                        }
                    }
                }
            }
            .padding(18)

            if let selectedWord {
                // Per-chip positioning ("beside the tapped word") kept
                // running into real bugs (popups clamped against an
                // estimated size that didn't match the actual rendered
                // content, cutting them off) -- dead simple beats clever
                // here: always centered on screen.
                //
                // .fixedSize() before .position() is required, not
                // decorative: .position() proposes its OWN parent's size
                // (here, the full ZStack -- essentially the whole screen)
                // down into the popup's content, rather than letting it
                // size to its natural content. That's what let the header
                // row's Spacer expand to fill nearly the whole screen width
                // -- obvious for a narrow vertical word's single tile
                // column, less obvious for a horizontal word's already-wide
                // tile row, but the same bug in both cases. .fixedSize()
                // forces the natural/ideal size to be computed first, and
                // .position() then just places that already-sized view.
                WordArrangementPopup(
                    word: selectedWord,
                    arrangement: arrangementProvider(selectedWord),
                    onDismiss: { self.selectedWord = nil }
                )
                .fixedSize()
                .position(x: screenSize.width / 2, y: screenSize.height / 2)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear { screenSize = geometry.size }
                    .onChange(of: geometry.size) { screenSize = $0 }
            }
        )
    }

    private func wordChip(_ word: String) -> some View {
        let wasFound = foundWords.contains(word)
        let isSelected = selectedWord == word
        return Text(word)
            .font(Theme.archivoMedium(12))
            .foregroundColor(wasFound ? Theme.ink : Theme.textMutedDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(wasFound ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color(hex: 0xF0E4CC)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.goldDeep, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: isSelected ? Theme.gold.opacity(0.8) : .clear, radius: isSelected ? 6 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                FeedbackPlayer.buttonTapped()
                selectedWord = (selectedWord == word) ? nil : word
            }
    }
}

/// The single scrollbar for the word list -- replaces the native ScrollView
/// indicator entirely (hidden at the call site) rather than layering a
/// second one on top of it. Press anywhere on the track and drag up/down to
/// scroll; faint tick marks show where each letter-length section starts.
/// Reports a 0...1 fraction of how far down the track the touch is. While
/// dragging, the thumb follows the touch directly; otherwise it follows
/// `model.fraction`, which the call site keeps live from the word list's
/// own scroll position -- so the thumb tracks the list whichever way it's
/// being moved, drag-the-scrubber or swipe-the-list. Observing `model`
/// here (rather than `SolverView` passing a plain `CGFloat` down) is
/// deliberate -- see `ScrollFractionModel`'s doc comment: this confines
/// the per-scroll-frame re-render to just this small view instead of all
/// of `SolverView`.
private struct WordListScrubber: View {
    let tickFractions: [CGFloat]
    @ObservedObject var model: ScrollFractionModel
    let onDrag: (CGFloat) -> Void

    @State private var isDragging = false
    @State private var thumbFraction: CGFloat = 0

    private let thumbHeight: CGFloat = 50

    private var displayedFraction: CGFloat {
        isDragging ? thumbFraction : model.fraction
    }

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = geometry.size.height
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Theme.textMutedDark.opacity(0.1))
                    .frame(width: 3)
                    .frame(maxWidth: .infinity)

                ForEach(Array(tickFractions.enumerated()), id: \.offset) { _, fraction in
                    Rectangle()
                        .fill(Theme.textMutedDark.opacity(0.28))
                        .frame(width: 8, height: 1.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(y: fraction * trackHeight)
                }

                Capsule()
                    .fill(isDragging ? Theme.goldDeep : Theme.gold)
                    .frame(width: 5, height: thumbHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(y: displayedFraction * max(0, trackHeight - thumbHeight))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let fraction = trackHeight > 0 ? min(max(value.location.y / trackHeight, 0), 1) : 0
                        thumbFraction = fraction
                        onDrag(fraction)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
    }
}

/// One physical tile placed within the popup's mini 2D layout, positioned
/// relative to the word's own reading line: `mainIndex` is how far along
/// that line it sits (0-based, one step per letter of the word), `lane` is
/// the offset perpendicular to that line (0 = on the line itself; a
/// perpendicular double tile's unused half juts out to lane -1 or +1,
/// mirroring which side its fixed letter order actually puts it on).
private enum ArrangementTile {
    case single(mainIndex: Int, letter: Character)
    case inline(mainIndex: Int, first: Character, second: Character)
    case perpendicular(mainIndex: Int, used: Character, other: Character, otherLane: Int)
}

private func arrangementTiles(for arrangement: WordArrangement) -> [ArrangementTile] {
    var tiles: [ArrangementTile] = []
    var mainIndex = 0
    var i = 0
    let slots = arrangement.slots
    while i < slots.count {
        switch slots[i] {
        case .single(let letter):
            tiles.append(.single(mainIndex: mainIndex, letter: letter))
            mainIndex += 1
            i += 1
        case .doublePerpendicular(let used, let other, let usedIsFirst):
            // usedIsFirst means the word passes through this tile's FIRST
            // letter, so its (unused) second letter sits one step further
            // along the tile's own fixed direction -- lane +1. The reverse
            // (used is the second letter) puts the unused first letter one
            // step back, lane -1.
            tiles.append(.perpendicular(mainIndex: mainIndex, used: used, other: other, otherLane: usedIsFirst ? 1 : -1))
            mainIndex += 1
            i += 1
        case .doubleInline(let letter, let isFirstOfPair):
            if isFirstOfPair, i + 1 < slots.count, case .doubleInline(let second, false) = slots[i + 1] {
                tiles.append(.inline(mainIndex: mainIndex, first: letter, second: second))
                mainIndex += 2
                i += 2
            } else {
                // Defensive fallback for a lone/mismatched inline slot --
                // shouldn't happen given how WordFinder always emits an
                // inline pair together, but avoids ever silently dropping
                // a letter from the display.
                tiles.append(.single(mainIndex: mainIndex, letter: letter))
                mainIndex += 1
                i += 1
            }
        }
    }
    return tiles
}

/// Lays a word's tiles out on a mini 2D grid mirroring the real board: a
/// single straight line of cells spells the word -- horizontal or
/// vertical, matching the direction it was actually found in -- so the
/// letters always read cleanly in one straight row or column. A
/// perpendicular double tile's unused half juts out to whichever side its
/// fixed letter order puts it on, fused to its partner with no seam, same
/// as a real board tile; it never disturbs the main line's alignment.
private struct ArrangementGridView: View {
    let arrangement: WordArrangement
    private let cellSize: CGFloat = 26
    private let gap: CGFloat = 2
    private var pitch: CGFloat { cellSize + gap }

    private var tiles: [ArrangementTile] { arrangementTiles(for: arrangement) }
    private var mainCount: Int { arrangement.slots.count }

    private var lanesBefore: Int {
        tiles.contains {
            if case .perpendicular(_, _, _, let lane) = $0 { return lane < 0 }
            return false
        } ? 1 : 0
    }

    private var lanesAfter: Int {
        tiles.contains {
            if case .perpendicular(_, _, _, let lane) = $0 { return lane > 0 }
            return false
        } ? 1 : 0
    }

    private var isHorizontal: Bool { arrangement.direction == .horizontal }

    var body: some View {
        let mainAxisLength = CGFloat(mainCount) * pitch - gap
        let crossAxisLength = CGFloat(1 + lanesBefore + lanesAfter) * pitch - gap

        ZStack(alignment: .topLeading) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                tileView(for: tile)
            }
        }
        .frame(
            width: isHorizontal ? mainAxisLength : crossAxisLength,
            height: isHorizontal ? crossAxisLength : mainAxisLength
        )
    }

    @ViewBuilder
    private func tileView(for tile: ArrangementTile) -> some View {
        switch tile {
        case .single(let mainIndex, let letter):
            wrapped { cell(String(letter)) }
                .frame(width: cellSize, height: cellSize)
                .position(point(mainStart: mainIndex, laneStart: 0, spanMain: 1, spanLane: 1))
        case .inline(let mainIndex, let first, let second):
            wrapped { lineStack { cell(String(first)); cell(String(second)) } }
                .frame(
                    width: isHorizontal ? cellSize * 2 + gap : cellSize,
                    height: isHorizontal ? cellSize : cellSize * 2 + gap
                )
                .position(point(mainStart: mainIndex, laneStart: 0, spanMain: 2, spanLane: 1))
        case .perpendicular(let mainIndex, let used, let other, let otherLane):
            wrapped {
                crossStack {
                    if otherLane < 0 {
                        cell(String(other))
                        cell(String(used), highlighted: true)
                    } else {
                        cell(String(used), highlighted: true)
                        cell(String(other))
                    }
                }
            }
            .frame(
                width: isHorizontal ? cellSize : cellSize * 2 + gap,
                height: isHorizontal ? cellSize * 2 + gap : cellSize
            )
            .position(point(mainStart: mainIndex, laneStart: min(0, otherLane), spanMain: 1, spanLane: 2))
        }
    }

    /// A stack running ALONG the word's main line -- used for an inline
    /// double tile, whose two cells are consecutive word positions.
    @ViewBuilder
    private func lineStack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isHorizontal {
            HStack(spacing: 0) { content() }
        } else {
            VStack(spacing: 0) { content() }
        }
    }

    /// A stack running PERPENDICULAR to the word's main line -- used for a
    /// perpendicular double tile's two cells.
    @ViewBuilder
    private func crossStack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isHorizontal {
            VStack(spacing: 0) { content() }
        } else {
            HStack(spacing: 0) { content() }
        }
    }

    @ViewBuilder
    private func wrapped<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(TileBackground())
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.tileBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func cell(_ text: String, highlighted: Bool = false) -> some View {
        Text(text)
            .font(Theme.archivoMedium(cellSize * 0.45))
            .foregroundColor(Theme.inkBoard)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(highlighted ? Theme.gold.opacity(0.45) : Color.clear)
    }

    /// Center point (for `.position`) of a tile spanning `spanMain` cells
    /// along the main axis starting at `mainStart`, and `spanLane` cells
    /// along the cross axis starting at `laneStart` (lane 0 = the main
    /// line; negative/positive = before/after it).
    private func point(mainStart: Int, laneStart: Int, spanMain: Int, spanLane: Int) -> CGPoint {
        let mainSize = CGFloat(spanMain) * cellSize + CGFloat(spanMain - 1) * gap
        let crossSize = CGFloat(spanLane) * cellSize + CGFloat(spanLane - 1) * gap
        let mainCenter = CGFloat(mainStart) * pitch + mainSize / 2
        let crossCenter = CGFloat(laneStart + lanesBefore) * pitch + crossSize / 2
        return isHorizontal ? CGPoint(x: mainCenter, y: crossCenter) : CGPoint(x: crossCenter, y: mainCenter)
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
                ArrangementGridView(arrangement: arrangement)
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
