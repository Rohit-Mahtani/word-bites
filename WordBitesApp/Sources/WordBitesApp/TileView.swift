import SwiftUI
import WordBitesKit

/// Renders one tile — a single square, or a fused two-cell domino in its
/// fixed orientation (never rotatable, matching the real game's rule). A
/// double tile is one continuous shape: a single border/background/shadow
/// wraps both letters, with no divider between them.
struct TileView: View {
    let tile: Tile
    let cellSize: CGFloat
    var isDragging = false

    var body: some View {
        // A blurred shadow has to be recomputed every frame for a view
        // whose position changes continuously -- expensive for the one
        // tile actively being dragged. `.drawingGroup()` fixes that by
        // rasterizing into a single Metal-backed layer, but applying it
        // unconditionally (an earlier attempt) rasterized every resting
        // tile too and visibly changed how they looked, which nobody asked
        // for. Scoped to only the actively-dragged tile instead: resting
        // tiles render exactly as before (byte-identical), and only the
        // one tile actually in motion is ever flattened, only while it's
        // moving.
        if isDragging {
            tileBody.drawingGroup()
        } else {
            tileBody
        }
    }

    private var tileBody: some View {
        content
            .background(TileBackground())
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.tileBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            // Two-layer shadow: a hard "lift" offset directly below, plus a
            // soft ambient shadow -- SwiftUI needs two stacked modifiers to
            // get both at once.
            .shadow(color: Theme.tileShadowHard.opacity(isDragging ? 0.45 : 0.35), radius: 0, x: 0, y: isDragging ? 4 : 3)
            .shadow(color: .black.opacity(isDragging ? 0.4 : 0.3), radius: isDragging ? 10 : 5, x: 0, y: isDragging ? 8 : 5)
    }

    @ViewBuilder
    private var content: some View {
        switch tile {
        case .single(let single):
            letterCell(String(single.letter))
                .frame(width: cellSize, height: cellSize)
        case .double(let double):
            let first = String(double.firstLetter)
            let second = String(double.secondLetter)
            if double.orientation == .horizontal {
                HStack(spacing: 0) {
                    letterCell(first)
                    letterCell(second)
                }
                .frame(width: cellSize * 2 + Theme.gap, height: cellSize)
            } else {
                VStack(spacing: 0) {
                    letterCell(first)
                    letterCell(second)
                }
                .frame(width: cellSize, height: cellSize * 2 + Theme.gap)
            }
        }
    }

    private func letterCell(_ text: String) -> some View {
        Text(text)
            .font(Theme.archivoMedium(cellSize * 0.45))
            .foregroundColor(Theme.inkBoard)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
