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
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)

            // The HUD floats on top, pinned to the top of the screen --
            // deliberately NOT part of the centering VStack above.
            VStack(spacing: 0) {
                HUDView(
                    mode: viewModel.mode,
                    score: viewModel.score,
                    wordCount: viewModel.foundWords.count,
                    timeRemaining: viewModel.timeRemaining,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onBackToHome: onBackToHome,
                    onBackToSolver: viewModel.quitGame
                )
                ScoreToastView(toast: viewModel.scoreToast)
                    .padding(.horizontal, 16)
                    .padding(.top, -8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
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
