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
            FullScreenCheckerboard(tileSize: 24, colorA: Theme.pageCheckerA, colorB: Theme.pageCheckerB)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HUDView(
                    mode: viewModel.mode,
                    score: viewModel.score,
                    wordCount: viewModel.foundWords.count,
                    timeRemaining: viewModel.timeRemaining,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onBackToHome: onBackToHome,
                    onBackToSolver: viewModel.quitGame
                )
                .padding(.horizontal, 10)

                ScoreToastView(toast: viewModel.scoreToast)
                    .padding(.horizontal, 10)

                Spacer(minLength: 0)

                if let loadError = viewModel.loadError {
                    Text(loadError)
                        .foregroundColor(Theme.pageText)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if viewModel.isDealing {
                    ProgressView("Dealing...")
                        .tint(Theme.pageText)
                        .foregroundColor(Theme.pageText)
                } else {
                    BoardView(viewModel: viewModel, cellSize: cellSize)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
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

    private static func cellSize(forAvailableWidth width: CGFloat) -> CGFloat {
        let usableWidth = min(width - 8, 700)
        let raw = (usableWidth - Theme.gap * CGFloat(Board.columnCount - 1)) / CGFloat(Board.columnCount)
        return max(30, min(56, raw))
    }
}
