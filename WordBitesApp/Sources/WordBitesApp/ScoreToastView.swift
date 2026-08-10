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

    // Keeps rendering the most recent word's text while fading out, so the
    // chip doesn't visibly shrink to empty right as it dismisses -- only
    // opacity/offset (below) control whether it's actually visible.
    @State private var displayed: ScoreToast?

    @State private var isVisible = false
    @State private var yOffset: CGFloat = 6

    var body: some View {
        HStack(spacing: 6) {
            Text(displayed?.word ?? "")
                .font(Theme.archivoSemiBold(16))
            Text(displayed.map { "+\($0.points)" } ?? "")
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
        .opacity(isVisible ? 1 : 0)
        .offset(y: yOffset)
        .frame(height: Self.height)
        .onChange(of: toast) { newValue in
            if let newValue {
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
                // Quick fade out -- no movement, just opacity.
                withAnimation(.easeOut(duration: 0.18)) {
                    isVisible = false
                }
            }
        }
    }
}
