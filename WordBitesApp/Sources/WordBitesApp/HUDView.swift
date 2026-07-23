import SwiftUI

/// Slim single-row bar — deliberately compact so the board stays the
/// visual center of the screen instead of the chrome. Left is a back arrow
/// to the welcome screen; right is a small "Solver" button that ends the
/// round early and shows the solver screen (quitGame() drives it via
/// GameViewModel.roundOver, same as a timed round running out).
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
            solverButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Theme.chrome, Theme.chromeMid, Theme.chromeDeep], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var solverButton: some View {
        Button(action: onBackToSolver) {
            Text("Solver")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.chromeText)
                .frame(width: 46, height: 46)
                .background(Theme.chromeText.opacity(0.12))
                .clipShape(Circle())
        }
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
