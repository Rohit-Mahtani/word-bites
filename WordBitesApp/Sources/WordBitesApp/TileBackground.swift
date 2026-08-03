import SwiftUI

/// One consistent tile color everywhere (singles and both halves of a
/// double), with a subtle diagonal grain layered on top so it reads as a
/// lightly-textured surface rather than a flat, plain fill -- matching the
/// look of tiles in the real Word Bites app.
struct TileBackground: View {
    var body: some View {
        Theme.tile
            .overlay(
                Canvas { context, size in
                    let step = max(size.width, size.height) / 3.2
                    var x = -size.height
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        context.stroke(path, with: .color(Theme.tileEdge.opacity(0.16)), lineWidth: 1.1)
                        x += step
                    }
                }
            )
    }
}
