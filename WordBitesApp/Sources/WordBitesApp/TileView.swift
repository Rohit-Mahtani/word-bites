import SwiftUI
import WordBitesKit

/// Renders one tile — a single square, or a fused two-cell domino in its
/// fixed orientation (never rotatable, matching the real game's rule).
struct TileView: View {
    let tile: Tile
    let cellSize: CGFloat
    var isDragging = false

    var body: some View {
        Group {
            switch tile {
            case .single(let single):
                letterCell(String(single.letter), background: Theme.tile)
                    .frame(width: cellSize, height: cellSize)
            case .double(let double):
                let first = String(double.firstLetter)
                let second = String(double.secondLetter)
                if double.orientation == .horizontal {
                    HStack(spacing: 0) {
                        letterCell(first, background: Theme.tileDouble)
                        Rectangle().fill(Theme.tileEdge).frame(width: 1)
                        letterCell(second, background: Theme.tileDouble)
                    }
                    .frame(width: cellSize * 2 + Theme.gap, height: cellSize)
                } else {
                    VStack(spacing: 0) {
                        letterCell(first, background: Theme.tileDouble)
                        Rectangle().fill(Theme.tileEdge).frame(height: 1)
                        letterCell(second, background: Theme.tileDouble)
                    }
                    .frame(width: cellSize, height: cellSize * 2 + Theme.gap)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(isDragging ? 0.5 : 0.3), radius: isDragging ? 10 : 3, x: 0, y: isDragging ? 6 : 2)
    }

    private func letterCell(_ text: String, background: Color) -> some View {
        Text(text)
            .font(.custom("Georgia-Bold", size: cellSize * 0.45))
            .foregroundColor(Theme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
    }
}
