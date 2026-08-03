import SwiftUI

/// A tile-styled single-character input. Typing anything keeps only the
/// most recently typed letter, so pasting or autocorrect can't leave more
/// than one character behind.
struct LetterInputTile: View {
    @Binding var letter: Character?
    var size: CGFloat = 46
    let field: CustomBoardFocusField
    var focusedField: FocusState<CustomBoardFocusField?>.Binding
    /// 0 when this tile is one half of a fused double-tile pair, whose
    /// *container* draws the single outer border/corner shape instead.
    var cornerRadius: CGFloat = 8
    var showBorder: Bool = true
    /// Rejects a typed letter if it wouldn't be valid here (e.g. it would
    /// duplicate the other half of the same double tile) -- true by default.
    var isValid: (Character) -> Bool = { _ in true }
    /// Fired once, right when this field goes from empty to filled with a
    /// valid letter -- the caller advances focus to the next empty field.
    var onFilled: () -> Void = {}

    @State private var text: String = ""

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.center)
            .font(Theme.archivoMedium(size * 0.42))
            .foregroundColor(Theme.ink)
            .frame(width: size, height: size)
            .background(
                Group {
                    if letter == nil {
                        Theme.emptySlotFill.opacity(0.14)
                    } else {
                        TileBackground()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                letter == nil ? Theme.emptySlotBorder.opacity(0.55) : Theme.tileBorder,
                                style: StrokeStyle(lineWidth: letter == nil ? 1.5 : 1, dash: letter == nil ? [4, 3] : [])
                            )
                    }
                }
            )
            .focused(focusedField, equals: field)
            .onChange(of: text) { newValue in
                let filtered = newValue.uppercased().filter(\.isLetter)
                var last = filtered.last.map(String.init) ?? ""
                if let ch = last.first, !isValid(ch) {
                    last = ""
                }
                text = last
                let wasEmpty = letter == nil
                letter = last.first
                if wasEmpty, letter != nil {
                    onFilled()
                }
            }
            .onAppear {
                if let letter { text = String(letter) }
            }
    }
}
