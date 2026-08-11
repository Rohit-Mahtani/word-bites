import SwiftUI

/// Reserves a fixed strip above the board and pops a word+points chip into
/// it whenever one is scored, replacing the old persistent "words found"
/// list entirely.
///
/// The chip view is always mounted -- it never inserts/removes from the
/// hierarchy -- and only its opacity/offset animate between shown and
/// hidden. An earlier version conditionally included the chip (`if let
/// toast { ... }.transition(...).id(toast.id)`), which mounts and unmounts
/// a real view on every word scored; that insertion/removal (and the
/// `.animation(value:)` driving it) could ripple into the surrounding
/// VStack's layout during the transition, which is very likely what caused
/// the board to visibly jitter specifically when words were scored. Opacity
/// and offset changes on an always-present view never affect layout, so
/// this can't repeat that.
struct ScoreToastView: View {
    let toast: ScoreToast?

    /// Exposed so the parent can center this chip in the gap between the
    /// HUD and the board without guessing its height.
    static let height: CGFloat = 40

    private static let exitDuration = 0.5

    // The front-most chip: the most recently scored word.
    @State private var displayed: ScoreToast?
    @State private var isVisible = false
    @State private var yOffset: CGFloat = 6

    // Whatever was in front right before `displayed` was replaced -- kept
    // on screen, slightly behind and smaller, fading out on its own
    // timeline instead of disappearing instantly when a new word arrives.
    @State private var previousDisplayed: ScoreToast?
    @State private var previousOpacity: Double = 0

    var body: some View {
        ZStack {
            if let previousDisplayed {
                chip(word: previousDisplayed.word, points: previousDisplayed.points)
                    .scaleEffect(0.94)
                    .offset(y: 6)
                    .opacity(previousOpacity)
                    .zIndex(0)
            }
            chip(word: displayed?.word ?? "", points: displayed?.points)
                .opacity(isVisible ? 1 : 0)
                .offset(y: yOffset)
                .zIndex(1)
        }
        .frame(height: Self.height)
        .onChange(of: toast) { newValue in
            if let newValue {
                // Demote whatever's currently in front to the "previous"
                // slot -- it stays visible, pushed behind the new chip,
                // and immediately starts fading out there instead of just
                // vanishing.
                if isVisible, let current = displayed {
                    previousDisplayed = current
                    previousOpacity = 1
                    withAnimation(.easeOut(duration: Self.exitDuration)) {
                        previousOpacity = 0
                    }
                }

                displayed = newValue
                // Instantly reset below its resting position -- even if a
                // previous toast is still mid fade-out -- so every word,
                // including back-to-back ones, gets its own upward pop
                // rather than just the first after a period of silence.
                withTransaction(Transaction(animation: nil)) {
                    isVisible = false
                    yOffset = 6
                }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    isVisible = true
                    yOffset = 0
                }
            } else {
                // Slow fade out -- no movement, just opacity.
                withAnimation(.easeOut(duration: Self.exitDuration)) {
                    isVisible = false
                }
            }
        }
    }

    private func chip(word: String, points: Int?) -> some View {
        HStack(spacing: 6) {
            Text(word)
                .font(Theme.archivoSemiBold(16))
            Text(points.map { "+\($0)" } ?? "")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.ink.opacity(0.65))
        }
        .foregroundColor(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Theme.gold, Theme.goldDeep], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}
