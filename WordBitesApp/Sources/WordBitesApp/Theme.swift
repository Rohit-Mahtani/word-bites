import SwiftUI

/// Same game-table palette validated in the browser prototype: felt board,
/// walnut chrome, bone tiles. One committed look, no light/dark variant —
/// matches the prototype's deliberate single-theme choice.
enum Theme {
    /// Spacing between adjacent board cells — also how much a double tile's
    /// footprint extends across the gap it straddles.
    static let gap: CGFloat = 4

    static let felt = Color(hex: 0x1F4A3D)
    static let feltDeep = Color(hex: 0x143025)
    static let wood = Color(hex: 0x5B3A24)
    static let woodDeep = Color(hex: 0x3E2717)
    static let woodLight = Color(hex: 0x7A5232)
    static let tile = Color(hex: 0xF2E8D0)
    static let tileDouble = Color(hex: 0xE8D6A0)
    static let tileEdge = Color(hex: 0xC9B98A)
    static let ink = Color(hex: 0x3B2A1E)
    static let cream = Color(hex: 0xF5EFE0)
    static let creamDim = Color(hex: 0xD8C9AB)
    static let accent = Color(hex: 0xC9A227)
    static let accentDeep = Color(hex: 0x9C7A18)
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
