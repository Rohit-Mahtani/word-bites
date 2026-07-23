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
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Theme.boardBlue, Theme.boardBlueDeep], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.chromeMid, lineWidth: 2)
            gridLines
        }
        .frame(width: boardWidth, height: boardHeight)
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
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
            .zIndex(isDragging ? 10 : 1)
            .gesture(
                DragGesture()
                    .onChanged { value in
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
                        let newTopLeft = CGPoint(
                            x: base.x + value.translation.width,
                            y: base.y + value.translation.height
                        )
                        let col = Int((newTopLeft.x / pitch).rounded())
                        let row = Int((newTopLeft.y / pitch).rounded())
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.attemptMove(tileID: tile.id, to: Position(column: col, row: row))
                            dragOffsets[tile.id] = nil
                            draggingTileID = nil
                            dragCandidateOrigin = nil
                        }
                        FeedbackPlayer.tilePlaced()
                    }
            )
    }
}
