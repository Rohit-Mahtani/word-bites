import SwiftUI
import WordBitesKit

/// The felt board: 8x9 grid, tiles absolutely positioned and draggable.
/// A tile's live drag is just a visual offset from its last committed
/// position — on release we compute the nearest cell, ask the view model
/// to commit or reject it, then animate to wherever it actually lands.
struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel
    let cellSize: CGFloat

    @State private var dragOffsets: [UUID: CGSize] = [:]
    @State private var draggingTileID: UUID?
    @State private var dragCandidateOrigin: Position?

    private var pitch: CGFloat { cellSize + Theme.gap }
    private var boardWidth: CGFloat { CGFloat(Board.columnCount) * pitch - Theme.gap }
    private var boardHeight: CGFloat { CGFloat(Board.rowCount) * pitch - Theme.gap }

    var body: some View {
        ZStack(alignment: .topLeading) {
            boardBackground
            dropZoneHighlight
            ForEach(viewModel.tiles, id: \.id) { tile in
                if let placement = viewModel.placement(for: tile.id) {
                    tileView(tile: tile, placement: placement)
                }
            }
        }
        .frame(width: boardWidth, height: boardHeight)
    }

    private var boardBackground: some View {
        ZStack {
            Theme.boardPanel
            gridLines
        }
        .frame(width: boardWidth, height: boardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // Approximates the spec's inset shadow (`inset 0 2px 10px
        // rgba(80,55,20,.2)`) -- SwiftUI has no native inset shadow, so a
        // soft inward-facing edge stroke stands in for it.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.dotTextureBase.opacity(0.2), lineWidth: 3)
                .blur(radius: 3)
                .mask(RoundedRectangle(cornerRadius: 10))
        )
    }

    private var gridLines: some View {
        Path { path in
            for c in 1..<Board.columnCount {
                let x = CGFloat(c) * pitch - Theme.gap / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: boardHeight))
            }
            for r in 1..<Board.rowCount {
                let y = CGFloat(r) * pitch - Theme.gap / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: boardWidth, y: y))
            }
        }
        .stroke(Theme.dotTextureBase.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
    }

    /// Highlights the cell(s) the currently-dragged tile would land on if
    /// released right now — green if that spot's valid, red if it isn't.
    @ViewBuilder
    private var dropZoneHighlight: some View {
        if let tileID = draggingTileID,
           let origin = dragCandidateOrigin,
           let tile = viewModel.tiles.first(where: { $0.id == tileID }) {
            let orientation = orientation(for: tile)
            let cells = Board.cells(origin: origin, cellCount: tile.cellCount, direction: orientation)
            let valid = viewModel.canPlace(tileID: tileID, at: origin)

            ForEach(cells.indices, id: \.self) { index in
                let cell = cells[index]
                if cell.column >= 0, cell.column < Board.columnCount, cell.row >= 0, cell.row < Board.rowCount {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(valid ? Color.green.opacity(0.35) : Color.red.opacity(0.35))
                        .frame(width: cellSize, height: cellSize)
                        .position(
                            x: CGFloat(cell.column) * pitch + cellSize / 2,
                            y: CGFloat(cell.row) * pitch + cellSize / 2
                        )
                }
            }
        }
    }

    private func orientation(for tile: Tile) -> TileOrientation {
        if case .double(let d) = tile { return d.orientation }
        return .horizontal
    }

    private func tileSize(for tile: Tile) -> CGSize {
        switch tile {
        case .single:
            return CGSize(width: cellSize, height: cellSize)
        case .double(let d):
            return d.orientation == .horizontal
                ? CGSize(width: cellSize * 2 + Theme.gap, height: cellSize)
                : CGSize(width: cellSize, height: cellSize * 2 + Theme.gap)
        }
    }

    private func topLeft(for placement: Placement) -> CGPoint {
        CGPoint(x: CGFloat(placement.origin.column) * pitch, y: CGFloat(placement.origin.row) * pitch)
    }

    private func tileView(tile: Tile, placement: Placement) -> some View {
        let size = tileSize(for: tile)
        let base = topLeft(for: placement)
        let offset = dragOffsets[tile.id] ?? .zero
        let isDragging = draggingTileID == tile.id

        return TileView(tile: tile, cellSize: cellSize, isDragging: isDragging)
            .frame(width: size.width, height: size.height)
            .position(x: base.x + size.width / 2 + offset.width, y: base.y + size.height / 2 + offset.height)
            // Scoped to just this tile's settled position (`base`, driven by
            // `placement`) so only the tile that actually moved animates.
            // Wrapping the view-model mutation itself in `withAnimation`
            // (the old approach) puts every tile, the HUD, and the board's
            // own layout into one shared animated transaction -- which both
            // blocked a new drag gesture on a different tile from being
            // recognized until that transaction settled, and let unrelated
            // layout (the board's position) get swept into the same
            // animation, causing it to visibly jitter.
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: base)
            .zIndex(isDragging ? 10 : 1)
            .gesture(
                // minimumDistance: 0 so this activates on the very first
                // touch, not after crossing a movement threshold -- pickup
                // sound, the green "valid drop zone" highlight, and the
                // lifted/shadowed visual state should all appear the moment
                // a tile is pressed, even if it's never actually dragged.
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Only one tile may be actively dragged at a time --
                        // each tile has its own independent DragGesture, so
                        // without this gate, a second finger on a different
                        // tile would start its own simultaneous drag. Once
                        // a tile has claimed the active drag, every other
                        // tile's gesture updates are ignored until it's
                        // released.
                        guard draggingTileID == nil || draggingTileID == tile.id else { return }
                        if draggingTileID != tile.id {
                            draggingTileID = tile.id
                            FeedbackPlayer.tilePickedUp()
                        }
                        dragOffsets[tile.id] = value.translation
                        let liveTopLeft = CGPoint(x: base.x + value.translation.width, y: base.y + value.translation.height)
                        dragCandidateOrigin = Position(
                            column: Int((liveTopLeft.x / pitch).rounded()),
                            row: Int((liveTopLeft.y / pitch).rounded())
                        )
                    }
                    .onEnded { value in
                        // Ignore a release from a tile that was never
                        // granted the active drag (see the guard above).
                        guard draggingTileID == tile.id else { return }
                        let newTopLeft = CGPoint(
                            x: base.x + value.translation.width,
                            y: base.y + value.translation.height
                        )
                        let col = Int((newTopLeft.x / pitch).rounded())
                        let row = Int((newTopLeft.y / pitch).rounded())
                        viewModel.attemptMove(tileID: tile.id, to: Position(column: col, row: row))
                        dragOffsets[tile.id] = nil
                        draggingTileID = nil
                        dragCandidateOrigin = nil
                        FeedbackPlayer.tilePlaced()
                    }
            )
    }
}
