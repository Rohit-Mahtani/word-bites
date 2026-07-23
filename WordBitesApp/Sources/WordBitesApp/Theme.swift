import SwiftUI

/// Blue + light brown/peach game-table palette. One committed look, no
/// light/dark variant. Chrome (HUD bars, headers) is now the LIGHT color,
/// which flips which text token belongs where:
///   - pageText / pageTextDim: light text for anything sitting directly on
///     a blue background (page glow, board).
///   - chromeText / chromeTextDim: dark text for anything sitting on the
///     light chrome bars (or on the gold accent buttons).
enum Theme {
    /// Spacing between adjacent board cells — also how much a double tile's
    /// footprint extends across the gap it straddles.
    static let gap: CGFloat = 4

    // Page background (radial gradient behind every screen).
    static let pageGlow = Color(hex: 0x3E7BA6)
    static let pageDeep = Color(hex: 0x122438)

    // Board surface: light blue checkerboard.
    static let boardCheckerA = Color(hex: 0xBFE0F2)
    static let boardCheckerB = Color(hex: 0xA8D3EA)

    // Game screen background (behind the board): darker blue checkerboard.
    static let pageCheckerA = Color(hex: 0x1B3A57)
    static let pageCheckerB = Color(hex: 0x16304A)

    // Chrome: HUD bar, headers — light brown/peach, replacing the old wood.
    static let chrome = Color(hex: 0xDDB98C)
    static let chromeMid = Color(hex: 0xC9986B)
    static let chromeDeep = Color(hex: 0xA9714A)

    // Tiles.
    static let tile = Color(hex: 0xF0CFA6)
    static let tileDouble = Color(hex: 0xE6B980)
    static let tileEdge = Color(hex: 0xC99A66)
    static let ink = Color.black

    // Text.
    static let pageText = Color(hex: 0xF5EFE0)
    static let pageTextDim = Color(hex: 0xD8CBB0)
    static let chromeText = Color(hex: 0x3B2A1E)
    static let chromeTextDim = Color(hex: 0x6B4E36)

    // Accent (unchanged gold) + semantic error.
    static let accent = Color(hex: 0xC9A227)
    static let accentDeep = Color(hex: 0x9C7A18)
    static let error = Color(hex: 0xB5533C)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
