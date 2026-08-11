import Foundation
import WordBitesKit

enum AppScreen: Equatable {
    case welcome
    case modeSelect
    case customBoard
    case presetBoards
    case playing
    case solver
    case stats
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var screen: AppScreen = .welcome

    // Mode-select's Timed/Untimed and Scoring Potential choices, lifted up
    // here (rather than local @State on ModeSelectView) so they persist
    // across navigating away and back -- e.g. finishing a round and hitting
    // "New Game" should return to whatever was last chosen, not reset to
    // these defaults every time. Only used to seed a fresh app launch.
    @Published var lastMode: GameMode = .timed
    @Published var lastScoringPotential: Double = 0
}
