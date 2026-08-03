import SwiftUI

/// The game screen's floating HUD block: a back button and a small "?"
/// (jumps to the solver early, same action the old "Solver" button had) on
/// one row, a cream score card below, and a floating time pill to its
/// right. This whole block floats over the board rather than pushing it
/// down -- see `GameView`.
struct HUDView: View {
    let mode: GameMode
    let score: Int
    let wordCount: Int
    let timeRemaining: Int
    let elapsedSeconds: Int
    let onBackToHome: () -> Void
    let onBackToSolver: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BackButton(action: onBackToHome, tint: Theme.ink, backgroundOpacity: 0.14)
                Spacer()
                helpButton
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("WORDS: \(wordCount)")
                    .font(Theme.archivoBold(13))
                    .tracking(0.6)
                    .foregroundColor(Theme.textMutedDark)
                Text("SCORE: \(String(format: "%04d", max(0, score)))")
                    .font(Theme.archivoBold(26))
                    .foregroundColor(Theme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.hudCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.16), radius: 9, x: 0, y: 4)

            HStack {
                Spacer()
                timePill
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var timePill: some View {
        let (text, isWarning): (String, Bool) = {
            switch mode {
            case .timed:
                let remaining = max(0, timeRemaining)
                return (Self.formatSeconds(remaining), remaining <= 15)
            case .untimed:
                return (Self.formatSeconds(elapsedSeconds), false)
            }
        }()
        return Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isWarning ? Theme.error : Theme.hudTimeText)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.ink.opacity(0.75))
            .clipShape(Capsule())
    }

    private var helpButton: some View {
        Button(action: onBackToSolver) {
            Text("?")
                .font(Theme.archivoBold(14))
                .foregroundColor(Theme.ink)
                .frame(width: 34, height: 34)
                .background(Theme.ink.opacity(0.14))
                .clipShape(Circle())
        }
    }

    private static func formatSeconds(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
