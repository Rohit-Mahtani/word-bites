import SwiftUI
import WordBitesKit

/// The felt board: 8x9 grid, tiles absolutely positioned and draggable.
/// A tile's live drag is just a visual offset from its last committed
/// position — on release we compute the nearest cell, ask the view model
/// to commit or reject it, then animate to wherever it actually lands.
struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel
    let cellSize: CGFloat

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
        DraggableTileView(
            tile: tile,
            cellSize: cellSize,
            pitch: pitch,
            base: topLeft(for: placement),
            size: tileSize(for: tile),
            isAnyOtherTileDragging: draggingTileID != nil && draggingTileID != tile.id,
            onDragStart: {
                draggingTileID = tile.id
                FeedbackPlayer.tilePickedUp()
            },
            onDragCandidateChange: { candidate in
                // Skip the write (and the re-render + canPlace board
                // simulation it triggers) when the rounded candidate cell
                // hasn't actually changed -- most sub-pixel touch deltas
                // during a drag round to the same cell as the previous
                // event.
                if dragCandidateOrigin != candidate {
                    dragCandidateOrigin = candidate
                }
            },
            onDragEnd: { finalOrigin in
                viewModel.attemptMove(tileID: tile.id, to: finalOrigin)
                draggingTileID = nil
                dragCandidateOrigin = nil
                FeedbackPlayer.tilePlaced()
            }
        )
        .zIndex(draggingTileID == tile.id ? 10 : 1)
    }
}

/// One tile's own live drag state and gesture, isolated from `BoardView`'s
/// state on purpose: `dragOffset`/`isDragging` used to live in `BoardView`
/// (`[UUID: CGSize]` + a `draggingTileID`), so every touch-move event on
/// *any* tile mutated `BoardView`'s own `@State` and forced its `body` to
/// re-run — which reconstructed all 11 tiles' full view (gradient, grain
/// texture, border, two shadows) on every single frame of a drag, not just
/// the one tile actually moving. A screen recording of real on-device
/// dragging confirmed this wasn't just perception: its own frame timestamps
/// showed genuine dropped frames (many 33-50ms gaps instead of the expected
/// ~17ms) concentrated exactly during dragging.
///
/// Keeping the live offset here instead means only *this* tile's `body`
/// re-runs as it's dragged — SwiftUI skips re-rendering a child view whose
/// own input properties (`tile`, `base`, ...) are unchanged between parent
/// re-renders, so the other 10 tiles do no work per frame. `BoardView`
/// still needs to know which tile is dragging (for the drop-zone highlight
/// and to block a second finger from starting another drag), so that part
/// is reported up via `onDragStart`/`onDragCandidateChange`/`onDragEnd`
/// rather than duplicated here.
///
/// Uses `DragGesture()`'s default minimum-distance threshold, not 0 -- an
/// earlier attempt lowered it to 0 (so pickup/drop sound and the drop-zone
/// highlight would fire on press, not just after real movement), but that
/// meant every sub-pixel touch jitter got processed as a live drag event
/// instead of being filtered out, and was the actual, confirmed cause of
/// persistent choppiness during fast dragging. Reverted; that press-based
/// sound/highlight feature is dropped in favor of keeping movement smooth.
private struct DraggableTileView: View {
    let tile: Tile
    let cellSize: CGFloat
    let pitch: CGFloat
    let base: CGPoint
    let size: CGSize
    let isAnyOtherTileDragging: Bool
    let onDragStart: () -> Void
    let onDragCandidateChange: (Position?) -> Void
    let onDragEnd: (Position) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        TileView(tile: tile, cellSize: cellSize, isDragging: isDragging)
            .frame(width: size.width, height: size.height)
            .position(x: base.x + size.width / 2 + dragOffset.width, y: base.y + size.height / 2 + dragOffset.height)
            // Scoped to just this tile's settled position (`base`, driven by
            // `placement`) so only the tile that actually moved animates.
            // Wrapping the view-model mutation itself in `withAnimation`
            // (an earlier approach) puts every tile, the HUD, and the
            // board's own layout into one shared animated transaction --
            // which both blocked a new drag gesture on a different tile
            // from being recognized until that transaction settled, and let
            // unrelated layout (the board's position) get swept into the
            // same animation, causing it to visibly jitter.
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: base)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only one tile may be actively dragged at a time --
                        // each tile has its own independent DragGesture, so
                        // without this gate, a second finger on a different
                        // tile would start its own simultaneous drag. Once
                        // a tile has claimed the active drag, every other
                        // tile's gesture updates are ignored until it's
                        // released.
                        guard !isAnyOtherTileDragging else { return }
                        if !isDragging {
                            isDragging = true
                            onDragStart()
                        }
                        dragOffset = value.translation
                        let liveTopLeft = CGPoint(x: base.x + value.translation.width, y: base.y + value.translation.height)
                        onDragCandidateChange(Position(
                            column: Int((liveTopLeft.x / pitch).rounded()),
                            row: Int((liveTopLeft.y / pitch).rounded())
                        ))
                    }
                    .onEnded { value in
                        // Ignore a release from a tile that was never
                        // granted the active drag (see the guard above).
                        guard isDragging else { return }
                        let newTopLeft = CGPoint(
                            x: base.x + value.translation.width,
                            y: base.y + value.translation.height
                        )
                        let col = Int((newTopLeft.x / pitch).rounded())
                        let row = Int((newTopLeft.y / pitch).rounded())
                        onDragEnd(Position(column: col, row: row))
                        dragOffset = .zero
                        isDragging = false
                    }
            )
    }
}
