import SwiftUI

/// A fixed-size checkerboard sized to an exact grid — used for the board
/// surface, where each square must line up with a real cell.
struct CheckerboardView: View {
    let columns: Int
    let rows: Int
    let cellSize: CGFloat
    let colorA: Color
    let colorB: Color

    var body: some View {
        Canvas { context, _ in
            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(
                        x: CGFloat(column) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    let color = (row + column).isMultiple(of: 2) ? colorA : colorB
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(columns) * cellSize, height: CGFloat(rows) * cellSize)
    }
}

/// A decorative checkerboard that fills whatever space it's given — used
/// for the page background behind the board, which doesn't need to align
/// to anything.
struct FullScreenCheckerboard: View {
    let tileSize: CGFloat
    let colorA: Color
    let colorB: Color

    var body: some View {
        Canvas { context, size in
            let columns = Int((size.width / tileSize).rounded(.up))
            let rows = Int((size.height / tileSize).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    let color = (row + column).isMultiple(of: 2) ? colorA : colorB
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}
