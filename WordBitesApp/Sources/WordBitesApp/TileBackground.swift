import SwiftUI

/// A tile's background: a diagonal warm-wood gradient with a fine grain
/// overlay, shared by every tile (single, double, and the custom-board
/// letter inputs) so they all read as the same material.
///
/// Equatable (trivially -- there are no stored properties, so every
/// instance is equal) purely so `.equatable()` at each call site lets
/// SwiftUI skip re-invoking this body -- and re-running the Canvas closure
/// below, which strokes a dozen-plus lines by hand -- every time the
/// *enclosing* tile view re-renders because its on-screen position changed
/// during a drag. The gradient and grain never change; only where the tile
/// sits does, and that's handled by the `.position()` modifier one level
/// up, not by anything in here.
struct TileBackground: View, Equatable {
    static func == (lhs: TileBackground, rhs: TileBackground) -> Bool { true }

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Theme.tileGradientStops[0], location: 0),
                .init(color: Theme.tileGradientStops[1], location: 0.45),
                .init(color: Theme.tileGradientStops[2], location: 0.70),
                .init(color: Theme.tileGradientStops[3], location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Canvas { context, size in
                let period: CGFloat = 6
                let strokeWidth: CGFloat = 1.5
                var x = -size.height
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    context.stroke(path, with: .color(Theme.tileGrain.opacity(0.10)), lineWidth: strokeWidth)
                    x += period
                }
            }
        )
    }
}
