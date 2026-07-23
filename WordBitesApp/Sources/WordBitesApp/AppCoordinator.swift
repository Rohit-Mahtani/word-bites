import Foundation

enum AppScreen: Equatable {
    case welcome
    case modeSelect
    case playing
    case solver
    case stats
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var screen: AppScreen = .welcome
}
