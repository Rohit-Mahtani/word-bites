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

    private var pitch: CGFloat { cellSize + Theme.gap }
    private var boardWidth: CGFloat { CGFloat(Board.columnCount) * pitch - Theme.gap }
    private var boardHeight: CGFloat { CGFloat(Board.rowCount) * pitch - Theme.gap }

    var body: some View {
        ZStack(alignment: .topLeading) {
            boardBackground
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
                .fill(LinearGradient(colors: [Theme.felt, Theme.feltDeep], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.woodLight, lineWidth: 2)
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
        .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
                        draggingTileID = tile.id
                        dragOffsets[tile.id] = value.translation
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
                        }
                    }
            )
    }
}
