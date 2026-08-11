import SwiftUI
import WordBitesKit

/// A scrollable list of pre-built boards (copied from real Word Bites
/// rounds) the player can drop straight into the custom board editor
/// instead of typing 16 letters by hand. Each row shows the preset's name
/// and a small preview of its exact tile layout.
struct PresetBoardsView: View {
    let onSelect: (PresetBoard) -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                    Text("Presets")
                        .font(Theme.archivoBold(26))
                        .foregroundColor(Theme.ink)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }

                Text("A handful of prebuilt, deliberately strong boards -- pick one to load it straight into the editor instead of typing 16 letters by hand.")
                    .font(Theme.archivoMedium(12))
                    .foregroundColor(Theme.textMutedMid)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(PresetBoards.all) { preset in
                            PresetRow(preset: preset, onSelect: { onSelect(preset) })
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(20)
        }
    }
}

private struct PresetRow: View {
    let preset: PresetBoard
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(preset.name)
                    .font(Theme.archivoSemiBold(16))
                    .foregroundColor(Theme.ink)
                Spacer()
                PresetPreviewView(tiles: preset.tiles)
            }
            .padding(12)
            .background(Theme.cardTranslucent)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// A tiny, non-interactive rendition of a preset's exact tile layout --
/// same fused-double-tile styling as the real board, scaled way down.
private struct PresetPreviewView: View {
    let tiles: [PresetTile]
    private let cellSize: CGFloat = 9
    private let gap: CGFloat = 1
    private var pitch: CGFloat { cellSize + gap }
    private var boardWidth: CGFloat { CGFloat(Board.columnCount) * pitch - gap }
    private var boardHeight: CGFloat { CGFloat(Board.rowCount) * pitch - gap }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.gameBottom
            ForEach(tiles.indices, id: \.self) { index in
                tileView(for: tiles[index])
            }
        }
        .frame(width: boardWidth, height: boardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func tileView(for tile: PresetTile) -> some View {
        let isDouble = tile.letters.count == 2
        let isHorizontalDouble = isDouble && tile.orientation == .horizontal
        let isVerticalDouble = isDouble && tile.orientation == .vertical
        let width: CGFloat = isHorizontalDouble ? cellSize * 2 + gap : cellSize
        let height: CGFloat = isVerticalDouble ? cellSize * 2 + gap : cellSize

        return Group {
            if isHorizontalDouble {
                HStack(spacing: 0) {
                    letterView(tile.letters[0])
                    letterView(tile.letters[1])
                }
            } else if isVerticalDouble {
                VStack(spacing: 0) {
                    letterView(tile.letters[0])
                    letterView(tile.letters[1])
                }
            } else {
                letterView(tile.letters[0])
            }
        }
        .frame(width: width, height: height)
        .background(TileBackground())
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .position(
            x: CGFloat(tile.column) * pitch + width / 2,
            y: CGFloat(tile.row) * pitch + height / 2
        )
    }

    private func letterView(_ letter: Character) -> some View {
        Text(String(letter))
            .font(.system(size: 6, weight: .semibold))
            .foregroundColor(Theme.inkBoard)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
