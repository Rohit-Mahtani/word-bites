import SwiftUI
import WordBitesKit

struct GameView: View {
    @ObservedObject var viewModel: GameViewModel
    let onBackToHome: () -> Void
    let onRoundFinished: () -> Void

    // Cached rather than recomputed inline from a GeometryReader read on
    // every body evaluation -- the per-second timer tick and every drag
    // update both re-evaluate this view's body, and repeatedly re-deriving
    // a layout-affecting value from a fresh geometry read on each of those
    // (rather than reusing a stable cached value) is what let the board's
    // computed size/position drift by fractions of a point and visibly
    // jitter. Only an actual change in available width should touch this.
    @State private var cellSize: CGFloat = 40

    // The bottom edge of the HUD's score card and the top edge of the board,
    // both measured (via the preference keys below) in the "game" coordinate
    // space that's anchored to this view's own top-left. The toast is
    // positioned at the midpoint between them so it always sits in the real
    // gap between the two -- rather than at a fixed offset from the HUD,
    // which drifted onto the board on devices where that gap is small.
    @State private var hudBottomY: CGFloat = 0
    @State private var boardTopY: CGFloat = 0

    var body: some View {
        ZStack {
            gameBackground

            // The board sits in its own container that fills the FULL
            // screen height and centers the board within it -- so the
            // board's vertical position never shifts when the HUD's own
            // height (below) changes, since the HUD isn't part of this
            // stack's layout at all.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                boardArea
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: BoardTopYPreferenceKey.self,
                                value: geometry.frame(in: .named("game")).minY
                            )
                        }
                    )
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)

            // The HUD floats on top, pinned to the top of the screen --
            // deliberately NOT part of the centering VStack above.
            HUDView(
                mode: viewModel.mode,
                score: viewModel.score,
                wordCount: viewModel.foundWords.count,
                timeRemaining: viewModel.timeRemaining,
                elapsedSeconds: viewModel.elapsedSeconds,
                onBackToHome: onBackToHome,
                onBackToSolver: viewModel.quitGame
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: HUDBottomYPreferenceKey.self,
                        value: geometry.frame(in: .named("game")).maxY
                    )
                }
            )

            // Sits in the gap between the HUD's score card and the board --
            // never overlapping either, regardless of how much (or little)
            // space that gap actually is on a given device.
            ScoreToastView(toast: viewModel.scoreToast)
                .padding(.top, toastTopOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .coordinateSpace(name: "game")
        .onPreferenceChange(HUDBottomYPreferenceKey.self) { hudBottomY = $0 }
        .onPreferenceChange(BoardTopYPreferenceKey.self) { boardTopY = $0 }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { cellSize = Self.cellSize(forAvailableWidth: geometry.size.width) }
                    .onChange(of: geometry.size.width) { newWidth in
                        cellSize = Self.cellSize(forAvailableWidth: newWidth)
                    }
            }
        )
        .onChange(of: viewModel.roundOver) { isOver in
            if isOver { onRoundFinished() }
        }
    }

    /// Midpoint of the HUD/board gap, minus half the toast's own height so
    /// the chip is centered in that gap rather than its top edge pinned
    /// there. Clamped so a not-yet-measured gap (both preference values
    /// still at their 0 default, on the very first layout pass) can't
    /// briefly place it off in the corner.
    private var toastTopOffset: CGFloat {
        guard boardTopY > hudBottomY else { return hudBottomY + 8 }
        let mid = (hudBottomY + boardTopY - ScoreToastView.height) / 2
        return max(hudBottomY + 4, mid)
    }

    private var gameBackground: some View {
        ZStack {
            LinearGradient(colors: [Theme.gameTop, Theme.gameBottom], startPoint: .top, endPoint: .bottom)
            DotTexture(color: Theme.dotTextureBase.opacity(0.14))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var boardArea: some View {
        if let loadError = viewModel.loadError {
            Text(loadError)
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)
                .padding()
        } else if viewModel.isDealing {
            ProgressView("Dealing...")
                .tint(Theme.ink)
                .foregroundColor(Theme.ink)
        } else {
            BoardView(viewModel: viewModel, cellSize: cellSize)
        }
    }

    private static func cellSize(forAvailableWidth width: CGFloat) -> CGFloat {
        let usableWidth = min(width - 8, 700)
        let raw = (usableWidth - Theme.gap * CGFloat(Board.columnCount - 1)) / CGFloat(Board.columnCount)
        return max(30, min(56, raw))
    }
}

private struct HUDBottomYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct BoardTopYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
