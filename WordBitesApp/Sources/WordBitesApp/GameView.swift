import SwiftUI
import WordBitesKit

struct GameView: View {
    @ObservedObject var viewModel: GameViewModel
    let onBackToHome: () -> Void
    let onRoundFinished: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cellSize = Self.cellSize(forAvailableWidth: geometry.size.width)

            ZStack {
                FullScreenCheckerboard(tileSize: 24, colorA: Theme.pageCheckerA, colorB: Theme.pageCheckerB)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    HUDView(
                        mode: viewModel.mode,
                        score: viewModel.score,
                        wordCount: viewModel.foundWords.count,
                        timeRemaining: viewModel.timeRemaining,
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
        }
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
