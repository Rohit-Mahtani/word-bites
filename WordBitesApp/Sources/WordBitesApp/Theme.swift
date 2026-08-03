import SwiftUI

/// Light warm "parchment" palette — Archivo type, wood-grain tiles, gold
/// accent. Most translucent variants (icon buttons, card fills, borders)
/// are built by applying `.opacity()` to one of the base browns below at
/// the call site rather than pre-naming every rgba combination from the
/// design spec; see call sites for the exact opacity each one uses.
enum Theme {
    /// Spacing between adjacent board cells — also how much a double tile's
    /// footprint extends across the gap it straddles.
    static let gap: CGFloat = 3

    // Page background gradient (Welcome, Mode Select, Solver, Custom Board,
    // High Scores).
    static let pageTop = Color(hex: 0xF6EFDD)
    static let pageBottom = Color(hex: 0xE9DCBC)

    // Game screen background gradient, plus the base color for its dotted
    // texture overlay (apply .opacity(0.14)) and the board's dotted grid
    // lines (apply .opacity(0.28)).
    static let gameTop = Color(hex: 0xDBC088)
    static let gameBottom = Color(hex: 0xCBAD70)
    static let dotTextureBase = Color(hex: 0x503714)

    // Board panel: the playing surface itself — a flat fill, deliberately a
    // different shade from the game screen background so it reads as a
    // distinct object sitting on the table.
    static let boardPanel = Color(hex: 0xE9DCBC)

    // Tiles: a diagonal 4-stop warm-wood gradient plus a grain overlay
    // (apply .opacity(0.10) to tileGrain).
    static let tileGradientStops: [Color] = [
        Color(hex: 0xF5DFB8), Color(hex: 0xE9C68E), Color(hex: 0xF3D8AC), Color(hex: 0xE2BA80)
    ]
    static let tileGrain = Color(hex: 0x785028)
    static let tileBorder = Color(hex: 0xC0925A)
    // Tile drop shadow is two layers: a hard "lift" offset (apply
    // .opacity(0.35)) plus a soft ambient shadow in plain black.
    static let tileShadowHard = Color(hex: 0x966432)

    // Text ink.
    static let ink = Color(hex: 0x3B2A1E)
    static let inkBoard = Color(hex: 0x3B2214)
    static let textMutedDark = Color(hex: 0x5A4632)
    static let textMutedMid = Color(hex: 0x8A7355)
    static let textMutedLight = Color(hex: 0x9C8465)

    // Gold accent (primary buttons, sliders, active segments) + secondary
    // brown accent (Solver's small round buttons, card fills).
    static let gold = Color(hex: 0xD9B23F)
    static let goldDeep = Color(hex: 0xB08E2E)
    static let brownAccent = Color(hex: 0xBD8B5E)
    static let cardTranslucent = Color.white.opacity(0.5)

    // HUD (game screen): the score card and the floating time pill.
    static let hudCard = Color(hex: 0xFBF3E2)
    static let hudTimeText = Color(hex: 0xF5EFE0)

    // Custom board empty-slot styling (dashed placeholder tiles).
    static let emptySlotFill = Color(hex: 0xC99A66)
    static let emptySlotBorder = Color(hex: 0xA9714A)

    static let error = Color(hex: 0xB5533C)

    static func archivoMedium(_ size: CGFloat) -> Font { .custom("ArchivoRoman-Medium", size: size) }
    static func archivoSemiBold(_ size: CGFloat) -> Font { .custom("ArchivoRoman-SemiBold", size: size) }
    static func archivoBold(_ size: CGFloat) -> Font { .custom("ArchivoRoman-Bold", size: size) }
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
