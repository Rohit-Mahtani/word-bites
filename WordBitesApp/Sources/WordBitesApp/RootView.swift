import SwiftUI

/// Owns the single long-lived `GameViewModel`, `StatsStore`, and
/// `CustomBoardStore` (so the dictionary/bigram pool, best-score tracking,
/// and any in-progress custom board all only ever live once) and switches
/// screens based on the coordinator.
struct RootView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var statsStore: StatsStore
    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var customBoardStore = CustomBoardStore()

    init() {
        let stats = StatsStore()
        _statsStore = StateObject(wrappedValue: stats)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(statsStore: stats))
    }

    var body: some View {
        switch coordinator.screen {
        case .welcome:
            WelcomeView(
                onSinglePlayer: { coordinator.screen = .modeSelect },
                onShowStats: { coordinator.screen = .stats }
            )

        case .modeSelect:
            ModeSelectView(
                onBack: { coordinator.screen = .welcome },
                onStart: { mode, scoringPotential, customDeal in
                    if let customDeal {
                        gameViewModel.startRound(mode: mode, customDeal: customDeal)
                    } else {
                        gameViewModel.startRound(mode: mode, scoringPotential: scoringPotential)
                    }
                    coordinator.screen = .playing
                },
                customBoardStore: customBoardStore,
                onEditCustomBoard: { coordinator.screen = .customBoard }
            )

        case .customBoard:
            CustomBoardView(
                store: customBoardStore,
                onBack: { coordinator.screen = .modeSelect }
            )

        case .playing:
            GameView(
                viewModel: gameViewModel,
                onBackToHome: { coordinator.screen = .welcome },
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

        case .stats:
            StatsView(statsStore: statsStore, onBack: { coordinator.screen = .welcome })
        }
    }
}
