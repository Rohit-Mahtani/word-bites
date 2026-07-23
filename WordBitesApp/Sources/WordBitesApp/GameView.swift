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
                RadialGradient(
                    colors: [Theme.pageGlow, Theme.pageDeep],
                    center: .init(x: 0.5, y: -0.1),
                    startRadius: 10,
                    endRadius: geometry.size.height
                )
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

                    ScoreToastView(toast: viewModel.scoreToast)

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
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
        .onChange(of: viewModel.roundOver) { isOver in
            if isOver { onRoundFinished() }
        }
    }

    private static func cellSize(forAvailableWidth width: CGFloat) -> CGFloat {
        let usableWidth = min(width - 28, 460)
        let raw = (usableWidth - Theme.gap * CGFloat(Board.columnCount - 1)) / CGFloat(Board.columnCount)
        return max(30, min(48, raw))
    }
}
