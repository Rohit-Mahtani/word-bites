import SwiftUI

/// Slim single-row bar — deliberately compact so the board stays the
/// visual center of the screen instead of the chrome.
struct HUDView: View {
    let mode: GameMode
    let score: Int
    let timeRemaining: Int
    let onNewGame: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            actionButton(title: "Quit", action: onQuit)

            Spacer()
            hudItem(label: "Score", value: "\(score)", tint: Theme.cream)

            if mode == .timed {
                Spacer()
                hudItem(
                    label: "Time",
                    value: "\(max(0, timeRemaining))",
                    tint: timeRemaining <= 15 ? Color(hex: 0xB5533C) : Theme.cream
                )
            }

            Spacer()
            actionButton(title: "New Game", action: onNewGame)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Theme.woodLight, Theme.wood, Theme.woodDeep], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.woodDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func hudItem(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(1.0)
                .foregroundColor(Theme.creamDim)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(tint)
        }
    }
}
