import SwiftUI

/// Reserves a fixed strip above the board and pops a word+points chip into
/// it whenever one is scored, replacing the old persistent "words found"
/// list entirely.
///
/// The chip view is always mounted -- it never inserts/removes from the
/// hierarchy -- and only its opacity/scale animate between shown and
/// hidden. An earlier version conditionally included the chip (`if let
/// toast { ... }.transition(...).id(toast.id)`), which mounts and unmounts
/// a real view on every word scored; that insertion/removal (and the
/// `.animation(value:)` driving it) could ripple into the surrounding
/// VStack's layout during the transition, which is very likely what caused
/// the board to visibly jitter specifically when words were scored. Opacity
/// and scale changes on an always-present view never affect layout, so
/// this can't repeat that.
struct ScoreToastView: View {
    let toast: ScoreToast?

    // Keeps rendering the most recent word's text while fading out, so the
    // chip doesn't visibly shrink to empty right as it dismisses -- only
    // opacity/scale (below) control whether it's actually visible.
    @State private var displayed: ScoreToast?

    // A separate multiplier on top of the show/hide scale, pulsed back to 1
    // from a slightly-shrunk starting point every time a *new* word arrives
    // -- including back-to-back words, where `toast` never actually goes
    // nil. That's what gives each word its own little pop instead of just
    // the very first one after a period of silence, without introducing any
    // delay/queueing: the text swap itself is still instant.
    @State private var popScale: CGFloat = 1

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
        .opacity(toast == nil ? 0 : 1)
        .scaleEffect((toast == nil ? 0.85 : 1) * popScale)
        .frame(height: 40)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast == nil)
        .onChange(of: toast) { newValue in
            guard let newValue else { return }
            displayed = newValue
            withTransaction(Transaction(animation: nil)) {
                popScale = 0.86
            }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                popScale = 1
            }
        }
    }
}
