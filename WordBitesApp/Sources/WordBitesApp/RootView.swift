import SwiftUI

/// Owns the single long-lived `GameViewModel` (so the dictionary/bigram
/// pool only ever load once) and switches screens based on the coordinator.
struct RootView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var gameViewModel = GameViewModel()

    var body: some View {
        switch coordinator.screen {
        case .welcome:
            WelcomeView(onSinglePlayer: { coordinator.screen = .modeSelect })

        case .modeSelect:
            ModeSelectView(
                onBack: { coordinator.screen = .welcome },
                onSelectMode: { mode in
                    gameViewModel.startRound(mode: mode)
                    coordinator.screen = .playing
                }
            )

        case .playing:
            GameView(
                viewModel: gameViewModel,
                onNewGame: { coordinator.screen = .modeSelect },
                onRoundFinished: { coordinator.screen = .solver }
            )

        case .solver:
            SolverView(
                allWords: gameViewModel.solverWords,
                foundWords: gameViewModel.foundWords,
                score: gameViewModel.score,
                isComputing: gameViewModel.isComputingSolverWords,
                onBack: { coordinator.screen = .welcome },
                onNewGame: { coordinator.screen = .modeSelect }
            )
        }
    }
}
