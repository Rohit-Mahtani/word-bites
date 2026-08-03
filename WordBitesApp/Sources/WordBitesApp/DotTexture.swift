import SwiftUI

/// A subtle repeating dot pattern that fills whatever space it's given —
/// used over the game screen's background gradient, and reused at the
/// board's own grid-line opacity for the board panel's cell dividers.
struct DotTexture: View {
    var spacing: CGFloat = 16
    var dotRadius: CGFloat = 1
    var color: Color = Theme.dotTextureBase.opacity(0.14)

    var body: some View {
        Canvas { context, size in
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
