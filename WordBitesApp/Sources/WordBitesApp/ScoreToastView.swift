import SwiftUI

/// Reserves a fixed strip above the board and pops a word+points chip into
/// it whenever one is scored, replacing the old persistent "words found"
/// list entirely.
struct ScoreToastView: View {
    let toast: ScoreToast?

    var body: some View {
        Group {
            if let toast {
                HStack(spacing: 6) {
                    Text(toast.word)
                        .font(.custom("Georgia-Bold", size: 18))
                    Text("+\(toast.points)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.boardBlueDeep)
                }
                .foregroundColor(Theme.chromeText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [Theme.chrome, Theme.chromeMid], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                .transition(.scale.combined(with: .opacity))
                .id(toast.id)
            }
        }
        .frame(height: 40)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast)
    }
}
