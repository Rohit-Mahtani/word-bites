import SwiftUI
import WordBitesKit

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        GeometryReader { geometry in
            let cellSize = Self.cellSize(forAvailableWidth: geometry.size.width)

            ZStack {
                RadialGradient(
                    colors: [Color(hex: 0x2A5C4C), Theme.feltDeep],
                    center: .init(x: 0.5, y: -0.1),
                    startRadius: 10,
                    endRadius: geometry.size.height
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    HUDView(
                        score: viewModel.score,
                        timeRemaining: viewModel.timeRemaining,
                        onNewBoard: viewModel.startRound
                    )

                    Spacer(minLength: 0)

                    if let loadError = viewModel.loadError {
                        Text(loadError)
                            .foregroundColor(Theme.cream)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if viewModel.isDealing {
                        ProgressView("Dealing...")
                            .tint(Theme.cream)
                            .foregroundColor(Theme.cream)
                    } else {
                        BoardView(viewModel: viewModel, cellSize: cellSize)
                    }

                    Spacer(minLength: 0)

                    FoundWordsView(words: viewModel.foundWords)
                }
                .padding(14)

                if viewModel.roundOver {
                    RoundEndOverlay(
                        score: viewModel.score,
                        words: viewModel.foundWords,
                        onPlayAgain: viewModel.startRound
                    )
                }
            }
        }
    }

    private static func cellSize(forAvailableWidth width: CGFloat) -> CGFloat {
        let usableWidth = min(width - 28, 460)
        let raw = (usableWidth - Theme.gap * CGFloat(Board.columnCount - 1)) / CGFloat(Board.columnCount)
        return max(30, min(48, raw))
    }
}
