import SwiftUI

/// Slim single-row bar — deliberately compact so the board stays the
/// visual center of the screen instead of the chrome. Both nav actions are
/// back arrows now: left always leaves for the welcome screen, right ends
/// the round and shows the solver (identical destination the old "Quit"
/// button used — quitGame() still drives it via GameViewModel.roundOver).
struct HUDView: View {
    let mode: GameMode
    let score: Int
    let wordCount: Int
    let timeRemaining: Int
    let onBackToHome: () -> Void
    let onBackToSolver: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            BackButton(action: onBackToHome, tint: Theme.chromeText, backgroundOpacity: 0.12)

            Spacer()
            hudItem(label: "Score", value: "\(score)")
            Spacer()
            hudItem(label: "Words", value: "\(wordCount)")

            if mode == .timed {
                Spacer()
                hudItem(
                    label: "Time",
                    value: "\(max(0, timeRemaining))",
                    tint: timeRemaining <= 15 ? Theme.error : Theme.chromeText
                )
            }

            Spacer()
            BackButton(action: onBackToSolver, tint: Theme.chromeText, backgroundOpacity: 0.12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Theme.chrome, Theme.chromeMid, Theme.chromeDeep], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func hudItem(label: String, value: String, tint: Color = Theme.chromeText) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(1.0)
                .foregroundColor(Theme.chromeTextDim)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(tint)
        }
    }
}
