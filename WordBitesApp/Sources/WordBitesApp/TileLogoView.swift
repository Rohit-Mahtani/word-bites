import SwiftUI

/// A wordmark rendered as actual game tiles. Each tile sits at
/// a slight independent rotation, following a fixed alternating pattern
/// (not randomized per render) for a hand-placed, tactile feel.
struct TileLogoView: View {
    let text: String
    var tileSize: CGFloat = 28
    var fontSize: CGFloat = 17
    var spacing: CGFloat = 4

    private static let rotations: [Double] = [-3.5, 2.5, -2, 3, -3, 1.5, -2.5, 2]

    private var characters: [Character] { Array(text) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(characters.indices, id: \.self) { index in
                let ch = characters[index]
                if ch == " " {
                    Color.clear.frame(width: tileSize * 0.4)
                } else {
                    let radius = max(3, tileSize * 0.19)
                    Text(String(ch))
                        .font(Theme.archivoMedium(fontSize))
                        .foregroundColor(Theme.ink)
                        .frame(width: tileSize, height: tileSize)
                        .background(TileBackground())
                        .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.tileBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                        .shadow(color: Theme.tileShadowHard.opacity(0.35), radius: 0, x: 0, y: 3)
                        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 5)
                        .rotationEffect(.degrees(Self.rotations[index % Self.rotations.count]))
                }
            }
        }
    }
}
