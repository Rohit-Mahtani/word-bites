import SwiftUI

/// The "WORD BITES" wordmark rendered as actual game tiles — reused at
/// different sizes on the welcome screen and (small) in the in-game HUD.
struct TileLogoView: View {
    let text: String
    var tileSize: CGFloat = 28
    var fontSize: CGFloat = 17
    var spacing: CGFloat = 4

    private var characters: [Character] { Array(text) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(characters.indices, id: \.self) { index in
                let ch = characters[index]
                if ch == " " {
                    Color.clear.frame(width: tileSize * 0.4)
                } else {
                    Text(String(ch))
                        .font(.custom("Georgia-Bold", size: fontSize))
                        .foregroundColor(Theme.ink)
                        .frame(width: tileSize, height: tileSize)
                        .background(Theme.tile)
                        .clipShape(RoundedRectangle(cornerRadius: max(3, tileSize * 0.15)))
                }
            }
        }
    }
}
